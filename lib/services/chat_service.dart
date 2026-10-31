import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../config/supabase_config.dart';
import '../models/models.dart';
import 'local_cache_service.dart';
import 'media_service.dart';
import 'realtime_service.dart';

/// Handles all chat-related data operations.
///
/// Local-first (§7.1): the SQLite cache is mandatory — the UI renders from
/// it; writes land locally first and re-sync via the outbox. Realtime
/// (§7.3): all events ride the single shared couple channel via
/// [RealtimeService.instance] — this service only routes the message stream.
class ChatService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();
  static const int _pageSize = 50;
  LocalCacheService? _cache;
  bool _ownsCache = false;
  MediaService? _mediaService;

  String? _coupleId;
  List<Channel> _channels = [];
  List<Channel> get channels => _channels;

  final Map<String, List<Message>> _messagesByChannel = {};
  final Set<String> _fetchingChannels = {};

  /// Local-first read: returns what's cached; if a channel has nothing yet
  /// (fresh install, first open), kicks off the server fetch and the UI
  /// rebuilds when it lands — no caller has to remember to load first.
  List<Message> messagesForChannel(String channelId) {
    final cached = _messagesByChannel[channelId];
    if ((cached == null || cached.isEmpty) &&
        !_fetchingChannels.contains(channelId)) {
      _fetchingChannels.add(channelId);
      loadMessages(channelId)
          .whenComplete(() => _fetchingChannels.remove(channelId));
    }
    return cached ?? [];
  }

  String? _activeChannelId;
  String? get activeChannelId => _activeChannelId;

  // ── Realtime (single shared couple channel) ─────────────────
  StreamSubscription<RealtimeMessageEvent>? _realtimeSub;
  StreamSubscription<void>? _reconnectSub;

  // ── Typing state (lives on RealtimeService now) ─────────────
  bool get partnerIsTyping => RealtimeService.instance.partnerIsTyping;

  // ── Random prompts ──────────────────────────────────────────
  final Random _random = Random();
  int _currentPromptIndex = 0;

  // ── Offline sync ────────────────────────────────────────────
  Timer? _syncTimer;
  bool _channelsLoadError = false;
  bool get channelsLoadError => _channelsLoadError;

  /// Initialize with couple ID and load channels.
  ///
  /// The cache is mandatory: if the caller doesn't inject one (e.g. its init
  /// failed in main), this service creates and owns its own instance rather
  /// than degrading to network-only.
  Future<void> initialize(String coupleId,
      {LocalCacheService? cache, MediaService? mediaService}) async {
    debugPrint('[ChatService] initialize enter couple=$coupleId cacheNull=${cache == null}');
    _coupleId = coupleId;
    _mediaService = mediaService;

    if (cache == null && _cache == null) {
      final own = LocalCacheService();
      try {
        // A dead/mismatched sqflite web worker can hang openDatabase forever —
        // time-box it so loadChannels and realtime still come up.
        await own.initialize().timeout(const Duration(seconds: 6));
        _cache = own;
        _ownsCache = true;
      } catch (e) {
        debugPrint('[ChatService] self-healed cache init failed: $e');
      }
    } else if (cache != null) {
      _cache = cache;
    }

    await loadChannels();
    await drainOutbox();

    // Route the shared couple stream into local state.
    _realtimeSub?.cancel();
    _realtimeSub = RealtimeService.instance.messageEvents
        .listen(_onRealtimeMessageEvent);

    // Reconnect = outbox drain + catch-up of the active channel.
    _reconnectSub?.cancel();
    _reconnectSub = RealtimeService.instance.connected.listen((_) async {
      await drainOutbox();
      final active = _activeChannelId;
      if (active != null) await loadMessages(active);
    });

    // Keep retrying offline writes even if no reconnect event fires.
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      drainOutbox();
    });
  }

  /// Drain the offline write queue.
  ///
  /// 1. Unsynced messages (messages.is_synced = 0) — inserted to the server.
  /// 2. Outbox ops (message.edit / message.delete / read.mark), in order.
  /// Both are idempotent: server events echo back and are deduped by id.
  Future<void> drainOutbox() async {
    final cache = _cache;
    if (cache == null) return;

    final unsynced = await cache.getUnsyncedMessages();
    for (final msg in unsynced) {
      try {
        await _client.from('messages').insert(msg.toInsertJson());
        await cache.markSynced(msg.id);
        debugPrint('[ChatService] synced offline message ${msg.id}');
      } catch (e) {
        debugPrint('[ChatService] offline message ${msg.id} still pending: $e');
        break; // keep order; retry next cycle
      }
    }

    final ops = await cache.getPendingOutbox();
    for (final op in ops) {
      try {
        await _applyOutboxOp(op['op'] as String, op['payload'] as String);
        await cache.deleteOutboxEntry(op['id'] as int);
      } catch (e) {
        await cache.bumpOutboxAttempt(op['id'] as int, e.toString());
        debugPrint('[ChatService] outbox op ${op['op']} pending: $e');
        break; // preserve ordering
      }
    }
  }

  Future<void> _applyOutboxOp(String op, String payloadJson) async {
    final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
    switch (op) {
      case 'message.edit':
        await _client.from('messages').update({
          'content': payload['content'] as String,
          'is_edited': true,
        }).eq('id', payload['id'] as String);
      case 'message.delete':
        await _client
            .from('messages')
            .update({'is_deleted': true, 'content': null})
            .eq('id', payload['id'] as String);
      case 'read.mark':
        await _client.rpc('batch_mark_read', params: {
          'p_channel_id': payload['channel_id'] as String,
          'p_user_id': payload['user_id'] as String,
        });
      default:
        debugPrint('[ChatService] unknown outbox op: $op');
    }
  }

  /// Fetch channels — cache-first, then sync from server.
  Future<void> loadChannels() async {
    debugPrint('[ChatService] loadChannels enter couple=$_coupleId');
    if (_coupleId == null) return;

    // 1. Load from cache instantly (a broken cache must never block the
    //    server sync below — degrade to network-only).
    if (_cache != null) {
      try {
        final cached = await _cache!.getChannels(_coupleId!);
        if (cached.isNotEmpty) {
          _channels = cached;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[ChatService] channel cache read failed (network-only): $e');
      }
    }

    // 2. Sync from server in background
    try {
      final data = await _client
          .from('channels')
          .select()
          .eq('couple_id', _coupleId!)
          .order('position');

      _channels = data.map((json) => Channel.fromJson(json)).toList();
      _cache?.saveChannels(_channels);
      _channelsLoadError = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading channels: $e');
      // If no cached channels either, flag the error for UI
      if (_channels.isEmpty) {
        _channelsLoadError = true;
        notifyListeners();
      }
    }
  }

  /// Fetch messages — cache-first, then sync from server.
  Future<void> loadMessages(String channelId, {bool loadMore = false}) async {
    final existing = _messagesByChannel[channelId] ?? [];

    // 1. Load from cache instantly (only on first load)
    if (!loadMore && _cache != null && existing.isEmpty) {
      final cached = await _cache!.getMessages(channelId, limit: _pageSize);
      if (cached.isNotEmpty) {
        _messagesByChannel[channelId] = cached;
        notifyListeners();
      }
    }

    // 2. Sync from server
    try {
      final current = _messagesByChannel[channelId] ?? [];

      PostgrestFilterBuilder<List<Map<String, dynamic>>> filterQuery = _client
          .from('messages')
          .select()
          .eq('channel_id', channelId);

      if (loadMore && current.isNotEmpty) {
        filterQuery = filterQuery.lt('created_at', current.last.createdAt.toIso8601String());
      }

      final data = await filterQuery
          .order('created_at', ascending: false)
          .limit(_pageSize);
      final messages = data.map((json) => Message.fromJson(json)).toList();

      if (loadMore) {
        _messagesByChannel[channelId] = [...current, ...messages];
      } else {
        _messagesByChannel[channelId] = messages;
      }

      // Save to cache
      _cache?.saveMessages(messages);
      
      // Auto-download media
      for (final msg in messages) {
        if (msg.mediaUrl != null) {
          _mediaService?.downloadMedia(msg.mediaUrl!);
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
      // If server fails, we still have cached data — no crash
    }
  }

  /// Get all messages that have location data (for the Memory Globe).
  Future<List<Message>> getMessagesWithLocation() async {
    if (_coupleId == null) return [];
    
    // Fallback to cache if offline
    if (_cache != null) {
      try {
        final cached = await _cache!.getMessagesWithLocation();
        if (cached.isNotEmpty) {
          return cached;
        }
      } catch (e) {
        debugPrint('Local cache error: $e');
      }
    }

    try {
      final data = await _client
          .from('messages')
          .select('*, channels!inner(couple_id)')
          .eq('channels.couple_id', _coupleId!)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      return data.map((json) {
        // Remove the joined channels object to match Message model
        final cleanJson = Map<String, dynamic>.from(json)..remove('channels');
        return Message.fromJson(cleanJson);
      }).toList();
    } catch (e) {
      debugPrint('Error loading messages with location: $e');
      return [];
    }
  }

  /// Send a message (optimistic UI).
  Future<void> sendMessage({
    required String channelId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    String? replyTo,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    // Optimistic message
    final optimistic = Message(
      id: id,
      channelId: channelId,
      senderId: senderId,
      coupleId: _coupleId,
      content: content,
      type: type,
      replyTo: replyTo,
      readBy: [senderId],
      createdAt: now,
      updatedAt: now,
      isPending: true,
    );

    // Insert at the beginning (newest first)
    final messages = _messagesByChannel[channelId] ?? [];
    _messagesByChannel[channelId] = [optimistic, ...messages];
    notifyListeners();

    // Save to local cache immediately (offline support)
    _cache?.saveMessage(optimistic, synced: false);

    try {
      await _client.from('messages').insert(optimistic.toInsertJson());
      _cache?.markSynced(id);
    } catch (e) {
      // Keep in cache with is_synced=false for retry
      // Only remove from UI if it's a permanent error
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Send a media message (image, video, or voice).
  /// Picks/receives a file, uploads via MediaService, then sends the message.
  Future<void> sendMediaMessage({
    required String channelId,
    required String senderId,
    required String coupleId,
    required MediaService mediaService,
    required XFile file,
    required MessageType type,
    String? caption,
    int? durationMs,
  }) async {
    final mediaType = type == MessageType.image
        ? MediaType.image
        : type == MessageType.video
            ? MediaType.video
            : MediaType.voice;

    final result = await mediaService.uploadFile(
      coupleId: coupleId,
      file: file,
      type: mediaType,
    );

    if (result == null) {
      throw Exception('Upload failed');
    }

    LocationData? location;
    if (type == MessageType.image) {
      location = await mediaService.extractLocationFromImage(file);
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    // Optimistic message — media_url now stores the private-bucket object
    // PATH (§7.2); the UI resolves it through MediaService, never by URL.
    final optimistic = Message(
      id: id,
      channelId: channelId,
      senderId: senderId,
      coupleId: _coupleId,
      content: caption,
      type: type,
      mediaUrl: result.url,
      mediaThumbnailUrl:
          result.blurHash != null ? 'blurhash:${result.blurHash}' : null,
      mediaSizeBytes: result.sizeBytes,
      mediaDurationMs: durationMs,
      latitude: location?.latitude,
      longitude: location?.longitude,
      readBy: [senderId],
      createdAt: now,
      updatedAt: now,
      isPending: true,
    );

    final messages = _messagesByChannel[channelId] ?? [];
    _messagesByChannel[channelId] = [optimistic, ...messages];
    notifyListeners();

    // Local-first: persist before the server write (§7.1)
    _cache?.saveMessage(optimistic, synced: false);

    try {
      await _client.from('messages').insert(optimistic.toInsertJson());
      _cache?.markSynced(id);
    } catch (e) {
      // Stays in the outbox queue; drainOutbox() retries.
      debugPrint('[ChatService] media message $id deferred to outbox: $e');
      rethrow;
    }
  }

  /// Route the shared couple stream into local state (§7.3).
  ///
  /// There is no per-channel socket anymore: all couple messages arrive on
  /// one stream. Only the active channel's in-memory list is updated; other
  /// channels still get everything persisted to the cache and reload from
  /// there when opened.
  void _onRealtimeMessageEvent(RealtimeMessageEvent event) {
    final cache = _cache;

    if (event.kind == RealtimeMessageEventKind.delete) {
      final id = event.message.id;
      for (final entry in _messagesByChannel.entries) {
        final idx = entry.value.indexWhere((m) => m.id == id);
        if (idx == -1) continue;
        final old = entry.value[idx];
        entry.value[idx] = Message(
          id: old.id,
          channelId: old.channelId,
          senderId: old.senderId,
          coupleId: old.coupleId,
          content: null,
          type: old.type,
          isDeleted: true,
          readBy: old.readBy,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
      }
      cache?.deleteMessage(id);
      notifyListeners();
      return;
    }

    final newMessage = event.message;
    final channelId = newMessage.channelId;

    if (event.kind == RealtimeMessageEventKind.insert) {
      cache?.saveMessage(newMessage);
      if (newMessage.mediaUrl != null) {
        _mediaService?.downloadMedia(newMessage.mediaUrl!);
      }
    }

    final messages = _messagesByChannel[channelId];
    if (messages == null) return; // not open in memory; cache has it

    final idx = messages.indexWhere((m) => m.id == newMessage.id);
    if (idx == -1) {
      if (event.kind == RealtimeMessageEventKind.insert) {
        _messagesByChannel[channelId] = [newMessage, ...messages];
        notifyListeners();
      }
      return;
    }

    // Replace optimistic / apply update
    messages[idx] = newMessage;
    notifyListeners();
  }

  /// Point the UI at a channel. No socket churn — the shared couple stream
  /// is already live; this only switches which in-memory list gets updated.
  void setActiveChannel(String channelId) {
    if (_activeChannelId == channelId) return;
    _activeChannelId = channelId;
    // Opening a screen must fetch its history — realtime only covers NEW
    // events, and reconnect catch-up only fires on reconnects.
    loadMessages(channelId);
  }

  void clearActiveChannel() {
    _activeChannelId = null;
  }

  /// Deprecated v1 name — kept so existing call sites keep compiling.
  /// No longer opens a dedicated socket (§7.3).
  @Deprecated('Use setActiveChannel — the shared couple channel is always on')
  void subscribeToMessages(String channelId) => setActiveChannel(channelId);

  /// Deprecated v1 name — kept so existing call sites keep compiling.
  @Deprecated('Use clearActiveChannel')
  void unsubscribeFromMessages() => clearActiveChannel();

  // ── Typing Indicators ──────────────────────────────────────

  /// Deprecated v1 name — typing now rides the shared couple channel.
  /// Kept so existing main.dart wiring keeps compiling (§7.3).
  @Deprecated('Typing is handled internally by the shared couple channel')
  void subscribeToTyping(String coupleId, String myUserId) {}

  /// Send a typing indicator over the shared couple channel.
  void sendTypingEvent(String coupleId, String userId) {
    RealtimeService.instance.sendTyping();
  }

  // ── Read Receipts ──────────────────────────────────────────

  /// Mark messages as read by the current user.
  /// Local-first (§7.1): cache + memory update immediately, server RPC best
  /// effort, outbox op if the RPC fails.
  Future<void> markMessagesAsRead(String channelId, String userId) async {
    // 1. Local apply
    final cache = _cache;
    if (cache != null) {
      await cache.markMessagesRead(channelId, userId);
    }

    final messages = _messagesByChannel[channelId];
    if (messages != null) {
      for (var i = 0; i < messages.length; i++) {
        if (!messages[i].readBy.contains(userId)) {
          messages[i] = Message(
            id: messages[i].id,
            channelId: messages[i].channelId,
            senderId: messages[i].senderId,
            coupleId: messages[i].coupleId,
            content: messages[i].content,
            type: messages[i].type,
            mediaUrl: messages[i].mediaUrl,
            mediaThumbnailUrl: messages[i].mediaThumbnailUrl,
            mediaDurationMs: messages[i].mediaDurationMs,
            mediaSizeBytes: messages[i].mediaSizeBytes,
            replyTo: messages[i].replyTo,
            isEdited: messages[i].isEdited,
            isDeleted: messages[i].isDeleted,
            readBy: [...messages[i].readBy, userId],
            createdAt: messages[i].createdAt,
            updatedAt: messages[i].updatedAt,
          );
        }
      }
      notifyListeners();
    }

    // 2. Server sync (outbox on failure)
    try {
      await _client.rpc('batch_mark_read', params: {
        'p_channel_id': channelId,
        'p_user_id': userId,
      });
    } catch (e) {
      debugPrint('[ChatService] read-mark deferred to outbox: $e');
      await _cache?.enqueueOutbox('read.mark', {
        'channel_id': channelId,
        'user_id': userId,
      });
    }
  }

  /// Create a new channel.
  Future<void> createChannel({
    required String name,
    String icon = '💬',
    String description = '',
  }) async {
    if (_coupleId == null) return;

    await _client.from('channels').insert({
      'couple_id': _coupleId,
      'name': name,
      'icon': icon,
      'description': description,
      'position': _channels.length,
    });

    await loadChannels();
  }

  /// Delete a message. Local-first (§7.1): tombstone locally now, server
  /// update best effort, outbox op on failure. The realtime update event
  /// that echoes back is deduped by id.
  Future<void> deleteMessage(String messageId, String channelId) async {
    // 1. Local apply
    final cache = _cache;
    if (cache != null) {
      await cache.deleteMessage(messageId);
    }

    final messages = _messagesByChannel[channelId];
    if (messages != null) {
      final idx = messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final old = messages[idx];
        messages[idx] = Message(
          id: old.id,
          channelId: old.channelId,
          senderId: old.senderId,
          coupleId: old.coupleId,
          content: null,
          type: old.type,
          isDeleted: true,
          readBy: old.readBy,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    }

    // 2. Server sync
    try {
      await _client
          .from('messages')
          .update({'is_deleted': true, 'content': null})
          .eq('id', messageId);
    } catch (e) {
      debugPrint('[ChatService] delete deferred to outbox: $e');
      await _cache?.enqueueOutbox('message.delete', {'id': messageId});
    }
  }

  /// Edit a message. Local-first (§7.1), outbox on server failure.
  Future<void> editMessage(String messageId, String channelId, String newContent) async {
    // 1. Local apply
    final cache = _cache;
    if (cache != null) {
      final cached = await cache.getMessages(channelId, limit: 10000);
      final cachedMsg = cached.where((m) => m.id == messageId).firstOrNull;
      if (cachedMsg != null) {
        await cache.saveMessage(cachedMsg.copyWithContent(newContent));
      }
    }

    final messages = _messagesByChannel[channelId];
    if (messages != null) {
      final idx = messages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final old = messages[idx];
        messages[idx] = Message(
          id: old.id,
          channelId: old.channelId,
          senderId: old.senderId,
          coupleId: old.coupleId,
          content: newContent,
          type: old.type,
          mediaUrl: old.mediaUrl,
          mediaThumbnailUrl: old.mediaThumbnailUrl,
          mediaDurationMs: old.mediaDurationMs,
          mediaSizeBytes: old.mediaSizeBytes,
          latitude: old.latitude,
          longitude: old.longitude,
          replyTo: old.replyTo,
          isEdited: true,
          isDeleted: false,
          readBy: old.readBy,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    }

    // 2. Server sync
    try {
      await _client.from('messages').update({
        'content': newContent,
        'is_edited': true,
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('[ChatService] edit deferred to outbox: $e');
      await _cache?.enqueueOutbox(
          'message.edit', {'id': messageId, 'content': newContent});
    }
  }

  // ── Plans (stored as structured messages) ──────────────────

  /// Get all plans for a channel (messages with type == plan).
  List<Plan> plansForChannel(String channelId) {
    final messages = _messagesByChannel[channelId] ?? [];
    return messages
        .where((m) => m.type == MessageType.plan && !m.isDeleted)
        .map((m) => Plan.fromMessage(m))
        .toList();
  }

  /// Create a new plan in a channel.
  Future<void> createPlan({
    required String channelId,
    required String senderId,
    required String title,
    String? description,
    String? location,
    DateTime? plannedDate,
  }) async {
    final planData = {
      'title': title,
      'description': description,
      'location': location,
      'planned_date': plannedDate?.toIso8601String(),
      'is_completed': false,
    };

    await sendMessage(
      channelId: channelId,
      senderId: senderId,
      content: jsonEncode(planData),
      type: MessageType.plan,
    );
  }

  /// Toggle plan completion status.
  Future<void> togglePlanCompleted(String messageId, String channelId, bool completed) async {
    final messages = _messagesByChannel[channelId];
    if (messages == null) return;

    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final msg = messages[idx];
    Map<String, dynamic> planData;
    try {
      planData = jsonDecode(msg.content ?? '{}');
    } catch (_) {
      planData = {'title': msg.content};
    }
    planData['is_completed'] = completed;

    await editMessage(messageId, channelId, jsonEncode(planData));
  }

  // ── Random Channel Helpers ────────────────────────────────

  /// Get the current conversation prompt.
  ConversationPrompt get currentPrompt {
    final prompts = SupabaseConfig.conversationPrompts;
    return prompts[_currentPromptIndex % prompts.length];
  }

  /// Get a new random prompt (different from current).
  ConversationPrompt nextRandomPrompt() {
    final prompts = SupabaseConfig.conversationPrompts;
    int newIndex;
    do {
      newIndex = _random.nextInt(prompts.length);
    } while (newIndex == _currentPromptIndex && prompts.length > 1);
    _currentPromptIndex = newIndex;
    notifyListeners();
    return prompts[_currentPromptIndex];
  }

  /// Get a random date night option.
  String getRandomDateNightOption() {
    final options = SupabaseConfig.dateNightOptions;
    return options[_random.nextInt(options.length)];
  }

  /// Find the #general channel (for quick actions).
  Channel? get generalChannel {
    try {
      return _channels.firstWhere((c) => c.type == ChannelType.general);
    } catch (_) {
      return _channels.isNotEmpty ? _channels.first : null;
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _realtimeSub?.cancel();
    _reconnectSub?.cancel();
    if (_ownsCache) {
      _cache?.close();
    }
    super.dispose();
  }
}
