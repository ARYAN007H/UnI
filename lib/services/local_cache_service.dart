import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../models/models.dart';

/// Local SQLite cache for WhatsApp-style local-first architecture.
/// Messages are stored locally first, then synced to/from Supabase.
class LocalCacheService extends ChangeNotifier {
  static Database? _db;
  static const _dbName = 'uni_cache.db';
  static const _dbVersion = 1;

  /// Initialize the database.
  Future<void> initialize() async {
    if (_db != null) return;
    
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      _db = await openDatabase(
        _dbName,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      debugPrint('[LocalCache] Web Database initialized');
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    debugPrint('[LocalCache] Database initialized at $path');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        channel_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        type TEXT DEFAULT 'text',
        media_url TEXT,
        media_local_path TEXT,
        media_thumbnail_url TEXT,
        media_duration_ms INTEGER,
        media_size_bytes INTEGER,
        latitude REAL,
        longitude REAL,
        reply_to TEXT,
        is_edited INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        read_by TEXT DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS channels (
        id TEXT PRIMARY KEY,
        couple_id TEXT NOT NULL,
        name TEXT NOT NULL,
        icon TEXT DEFAULT '💬',
        description TEXT DEFAULT '',
        position INTEGER DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS media_cache (
        media_url TEXT PRIMARY KEY,
        local_path TEXT NOT NULL,
        size_bytes INTEGER,
        downloaded_at TEXT NOT NULL
      )
    ''');

    // Indexes
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_msg_channel ON messages(channel_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_msg_synced ON messages(is_synced)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_channels_couple ON channels(couple_id)');

    debugPrint('[LocalCache] Tables created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  Database get db {
    if (_db == null) throw StateError('LocalCacheService not initialized');
    return _db!;
  }

  // ── Messages ─────────────────────────────────────────────

  /// Save a single message to local cache.
  Future<void> saveMessage(Message msg, {bool synced = true}) async {
    await db.insert(
      'messages',
      _messageToRow(msg, synced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Save multiple messages (batch insert from server sync).
  Future<void> saveMessages(List<Message> messages, {bool synced = true}) async {
    final batch = db.batch();
    for (final msg in messages) {
      batch.insert(
        'messages',
        _messageToRow(msg, synced),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get cached messages for a channel (newest first).
  Future<List<Message>> getMessages(String channelId,
      {int limit = 50, int offset = 0}) async {
    final rows = await db.query(
      'messages',
      where: 'channel_id = ?',
      whereArgs: [channelId],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_rowToMessage).toList();
  }

  /// Get unsynced messages (for offline queue).
  Future<List<Message>> getUnsyncedMessages() async {
    final rows = await db.query(
      'messages',
      where: 'is_synced = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  /// Get messages that have location data.
  Future<List<Message>> getMessagesWithLocation() async {
    final rows = await db.query(
      'messages',
      where: 'latitude IS NOT NULL AND longitude IS NOT NULL AND is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToMessage).toList();
  }

  /// Mark a message as synced.
  Future<void> markSynced(String messageId) async {
    await db.update(
      'messages',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Mark messages as read in local cache.
  Future<void> markMessagesRead(String channelId, String userId) async {
    final rows = await db.query(
      'messages',
      columns: ['id', 'read_by'],
      where: 'channel_id = ?',
      whereArgs: [channelId],
    );

    final batch = db.batch();
    for (final row in rows) {
      final readBy = List<String>.from(jsonDecode(row['read_by'] as String? ?? '[]'));
      if (!readBy.contains(userId)) {
        readBy.add(userId);
        batch.update(
          'messages',
          {'read_by': jsonEncode(readBy)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Delete a message locally.
  Future<void> deleteMessage(String messageId) async {
    await db.update(
      'messages',
      {'is_deleted': 1, 'content': null},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Get total message count for a channel.
  Future<int> getMessageCount(String channelId) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE channel_id = ?',
      [channelId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Search messages by content.
  Future<List<Message>> searchMessages(String query, {String? channelId}) async {
    final where = channelId != null
        ? 'content LIKE ? AND channel_id = ? AND is_deleted = 0'
        : 'content LIKE ? AND is_deleted = 0';
    final whereArgs = channelId != null ? ['%$query%', channelId] : ['%$query%'];

    final rows = await db.query(
      'messages',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 50,
    );
    return rows.map(_rowToMessage).toList();
  }

  // ── Channels ─────────────────────────────────────────────

  /// Save channels to local cache.
  Future<void> saveChannels(List<Channel> channels) async {
    final batch = db.batch();
    for (final ch in channels) {
      batch.insert(
        'channels',
        {
          'id': ch.id,
          'couple_id': ch.coupleId,
          'name': ch.name,
          'icon': ch.icon,
          'description': ch.description,
          'position': ch.position,
          'is_default': ch.isDefault ? 1 : 0,
          'created_at': ch.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get cached channels for a couple.
  Future<List<Channel>> getChannels(String coupleId) async {
    final rows = await db.query(
      'channels',
      where: 'couple_id = ?',
      whereArgs: [coupleId],
      orderBy: 'position ASC',
    );
    return rows
        .map((r) => Channel(
              id: r['id'] as String,
              coupleId: r['couple_id'] as String,
              name: r['name'] as String,
              icon: r['icon'] as String? ?? '💬',
              description: r['description'] as String? ?? '',
              position: r['position'] as int? ?? 0,
              isDefault: (r['is_default'] as int? ?? 0) == 1,
              createdAt: DateTime.parse(r['created_at'] as String),
            ))
        .toList();
  }

  // ── Media Cache ──────────────────────────────────────────

  /// Record a downloaded media file's local path.
  Future<void> cacheMediaPath(String mediaUrl, String localPath, {int? sizeBytes}) async {
    if (kIsWeb) return;
    await db.insert(
      'media_cache',
      {
        'media_url': mediaUrl,
        'local_path': localPath,
        'size_bytes': sizeBytes,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get local path for a cached media URL.
  Future<String?> getMediaLocalPath(String mediaUrl) async {
    if (kIsWeb) return null;
    final rows = await db.query(
      'media_cache',
      columns: ['local_path'],
      where: 'media_url = ?',
      whereArgs: [mediaUrl],
    );
    if (rows.isEmpty) return null;
    return rows.first['local_path'] as String?;
  }

  /// Get total cache size in bytes.
  Future<int> getCacheSize() async {
    if (kIsWeb) return 0;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(size_bytes), 0) as total FROM media_cache',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Sync State ───────────────────────────────────────────

  /// Get last sync timestamp for a key.
  Future<DateTime?> getLastSync(String key) async {
    final rows = await db.query(
      'sync_state',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['value'] as String);
  }

  /// Set last sync timestamp.
  Future<void> setLastSync(String key, DateTime timestamp) async {
    await db.insert(
      'sync_state',
      {
        'key': key,
        'value': timestamp.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Database Management ──────────────────────────────────

  /// Get the database file path (for backup).
  Future<String> getDatabasePath() async {
    if (kIsWeb) return '';
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbName);
  }

  /// Clear all cached data.
  Future<void> clearAll() async {
    await db.delete('messages');
    await db.delete('channels');
    await db.delete('media_cache');
    await db.delete('sync_state');
    debugPrint('[LocalCache] All data cleared');
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Helpers ──────────────────────────────────────────────

  Map<String, dynamic> _messageToRow(Message msg, bool synced) => {
        'id': msg.id,
        'channel_id': msg.channelId,
        'sender_id': msg.senderId,
        'content': msg.content,
        'type': msg.type.name,
        'media_url': msg.mediaUrl,
        'media_thumbnail_url': msg.mediaThumbnailUrl,
        'media_duration_ms': msg.mediaDurationMs,
        'media_size_bytes': msg.mediaSizeBytes,
        'latitude': msg.latitude,
        'longitude': msg.longitude,
        'reply_to': msg.replyTo,
        'is_edited': msg.isEdited ? 1 : 0,
        'is_deleted': msg.isDeleted ? 1 : 0,
        'read_by': jsonEncode(msg.readBy),
        'created_at': msg.createdAt.toIso8601String(),
        'updated_at': msg.updatedAt.toIso8601String(),
        'is_synced': synced ? 1 : 0,
      };

  Message _rowToMessage(Map<String, dynamic> row) => Message(
        id: row['id'] as String,
        channelId: row['channel_id'] as String,
        senderId: row['sender_id'] as String,
        content: row['content'] as String?,
        type: _parseType(row['type'] as String?),
        mediaUrl: row['media_url'] as String?,
        mediaThumbnailUrl: row['media_thumbnail_url'] as String?,
        mediaDurationMs: row['media_duration_ms'] as int?,
        mediaSizeBytes: row['media_size_bytes'] as int?,
        latitude: row['latitude'] as double?,
        longitude: row['longitude'] as double?,
        replyTo: row['reply_to'] as String?,
        isEdited: (row['is_edited'] as int? ?? 0) == 1,
        isDeleted: (row['is_deleted'] as int? ?? 0) == 1,
        readBy: List<String>.from(
            jsonDecode(row['read_by'] as String? ?? '[]')),
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );

  MessageType _parseType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      case 'plan':
        return MessageType.plan;
      default:
        return MessageType.text;
    }
  }
}
