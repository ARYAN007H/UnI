import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'local_cache_service.dart';

class ExportResult {
  /// Directory containing the bundle (native), null on web.
  final String? directory;

  /// The full manifest JSON (native writes it to disk; web returns it for
  /// an in-browser download).
  final String manifestJson;

  final int messageCount;
  final int mediaCount;

  const ExportResult({
    this.directory,
    required this.manifestJson,
    required this.messageCount,
    required this.mediaCount,
  });
}

/// One-click full export — the Trust-Displacement Play's trust artifact
/// (plan §8 Phase 3, pulled early for Settings).
///
/// Assembles everything from the LOCAL-FIRST SQLite database (§7.1): all
/// channels, all messages (including media metadata), daily answers, plus
/// copies of every locally-cached media file. No server round-trips — your
/// data lives on your device, so export is a file copy.
///
/// Native: writes `export_<timestamp>/manifest.json` + `media/` under the
/// documents directory and returns the path (UI hands it to a share sheet).
/// Web: returns the manifest JSON for a browser download (sqflite-ffi has
/// the data, but files aren't addressable there).
class ExportService {
  final LocalCacheService? _cache;

  ExportService({LocalCacheService? cache}) : _cache = cache;

  /// Build the manifest (pure — unit-testable).
  static Map<String, dynamic> buildManifest({
    required String coupleId,
    required List<Map<String, dynamic>> channels,
    required Map<String, List<Map<String, dynamic>>> messagesByChannel,
    required List<Map<String, dynamic>> dailyAnswers,
    required List<Map<String, dynamic>> mediaEntries,
  }) {
    var messageCount = 0;
    messagesByChannel.forEach((_, list) => messageCount += list.length);

    return {
      'format': 'uandi-export',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'couple_id': coupleId,
      'stats': {
        'channels': channels.length,
        'messages': messageCount,
        'daily_answers': dailyAnswers.length,
        'media_files': mediaCount(mediaEntries),
      },
      'channels': channels,
      'messages_by_channel': messagesByChannel,
      'daily_answers': dailyAnswers,
      'media': mediaEntries
          .map((m) => {
                'ref': m['media_url'],
                'file': _mediaFileName(m['media_url'] as String?),
                'cached_locally': m['local_path'] != null,
              })
          .toList(),
    };
  }

  static int mediaCount(List<Map<String, dynamic>> mediaEntries) =>
      mediaEntries.where((m) => m['local_path'] != null).length;

  static String? _mediaFileName(String? ref) {
    if (ref == null) return null;
    if (ref.startsWith('http')) return Uri.parse(ref).pathSegments.last;
    return ref.split('/').last;
  }

  /// Full export. Progress callback receives (done, total) for media copies.
  Future<ExportResult> exportAll({
    required String coupleId,
    void Function(int done, int total)? onMediaProgress,
  }) async {
    final cache = _cache;
    if (cache == null) {
      throw StateError('ExportService needs a LocalCacheService');
    }

    final channels = await cache.getChannels(coupleId);
    final messagesByChannel = <String, List<Map<String, dynamic>>>{};
    var messageCount = 0;
    for (final channel in channels) {
      final messages = await cache.getMessages(channel.id, limit: 100000);
      messagesByChannel[channel.id] = messages
          .map((m) => {
                'id': m.id,
                'channel_id': m.channelId,
                'sender_id': m.senderId,
                'content': m.content,
                'type': m.type.name,
                'media_url': m.mediaUrl,
                'latitude': m.latitude,
                'longitude': m.longitude,
                'created_at': m.createdAt.toIso8601String(),
                'is_edited': m.isEdited,
                'is_deleted': m.isDeleted,
              })
          .toList();
      messageCount += messages.length;
    }

    final dailyAnswers = await cache.getAllDailyAnswers(coupleId);
    final mediaEntries = await cache.listCachedMedia();

    final manifest = buildManifest(
      coupleId: coupleId,
      channels: channels
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'icon': c.icon,
                'description': c.description,
                'created_at': c.createdAt.toIso8601String(),
              })
          .toList(),
      messagesByChannel: messagesByChannel,
      dailyAnswers: dailyAnswers,
      mediaEntries: mediaEntries,
    );
    final manifestJson = const JsonEncoder.withIndent('  ').convert(manifest);

    if (kIsWeb) {
      return ExportResult(
        manifestJson: manifestJson,
        messageCount: messageCount,
        mediaCount: mediaCount(mediaEntries),
      );
    }

    // Native: assemble the bundle directory.
    final docs = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp('[:.]'), '-')
        .substring(0, 19);
    final exportDir = Directory(p.join(docs.path, 'uandi_export_$stamp'));
    await exportDir.create(recursive: true);
    await File(p.join(exportDir.path, 'manifest.json'))
        .writeAsString(manifestJson);

    final mediaDir = Directory(p.join(exportDir.path, 'media'));
    await mediaDir.create(recursive: true);

    final exportable =
        mediaEntries.where((m) => m['local_path'] != null).toList();
    var done = 0;
    for (final entry in exportable) {
      final source = File(entry['local_path'] as String);
      if (await source.exists()) {
        final name = _mediaFileName(entry['media_url'] as String?) ??
            'media_${done.toString().padLeft(6, '0')}';
        await source.copy(p.join(mediaDir.path, name));
      }
      done++;
      onMediaProgress?.call(done, exportable.length);
    }

    debugPrint('[Export] bundle at ${exportDir.path} '
        '($messageCount messages, ${exportable.length} media files)');

    return ExportResult(
      directory: exportDir.path,
      manifestJson: manifestJson,
      messageCount: messageCount,
      mediaCount: exportable.length,
    );
  }
}
