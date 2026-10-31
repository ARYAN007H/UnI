import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto_service.dart';
import 'local_cache_service.dart';

class AccountDeletionResult {
  final bool success;
  final String? error;
  final List<String> details;

  const AccountDeletionResult({
    required this.success,
    this.error,
    this.details = const [],
  });
}

/// Store-compliance account deletion (Apple 5.1.1(v) / Play policy) — the
/// FULL WIPE required by the compliance shell (plan §8 Phase 3, council
/// member #9's existential-risk mitigation).
///
/// Order matters and is deliberately server-first:
///   1. Edge Function `delete-account` (service role): storage objects,
///      couple row (FK cascade → channels/messages/answers/escrow),
///      profile row (cascade → devices/reports/blocks), auth user.
///   2. R2 media prefix via `media-url` action 'delete-prefix'
///      (R2 has no FK cascade — explicit wipe).
///   3. ONLY after the server confirms: local wipe — cached media files,
///      SQLite (outbox, messages, answers), secure-storage keys — then
///      signOut. If the server fails we DO NOT wipe locally: the user
///      keeps their data and can retry (never destroy without confirmation).
class AccountDeletionService {
  AccountDeletionService({
    SupabaseClient? client,
    CryptoService? crypto,
    LocalCacheService? cache,
  })  : _clientOverride = client,
        _crypto = crypto ?? CryptoService(),
        _cache = cache;

  final SupabaseClient? _clientOverride;
  final CryptoService _crypto;
  final LocalCacheService? _cache;

  /// Resolved lazily so pure-Dart unit tests can construct the service.
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// Idempotent where possible; safe to call again after a partial failure.
  Future<AccountDeletionResult> deleteAccount(String userId) async {
    final details = <String>[];

    // 1. Server-side full wipe.
    try {
      final response = await _client.functions.invoke(
        'delete-account',
        body: {'confirmed': true},
      );
      final data = response.data as Map<dynamic, dynamic>?;
      if (data == null || data['ok'] != true) {
        final err = data?['error'] as String? ?? 'unknown server error';
        final serverDetails =
            (data?['details'] as List<dynamic>?)?.cast<String>() ?? const [];
        return AccountDeletionResult(
          success: false,
          error: err,
          details: [...serverDetails],
        );
      }
    } catch (e) {
      return AccountDeletionResult(
        success: false,
        error: 'delete-account function unreachable',
        details: [e.toString()],
      );
    }

    // 2. R2 media prefix (best effort — function may be unconfigured pre-R2).
    final coupleId = await _currentCoupleId();
    if (coupleId != null) {
      try {
        await _client.functions.invoke('media-url', body: {
          'action': 'delete-prefix',
          'path': coupleId,
        });
      } catch (e) {
        details.add('r2 prefix wipe skipped: $e');
      }
    }

    // 3. Local wipe — only reached after the server confirmed deletion.
    try {
      await wipeLocalData(userId);
    } catch (e) {
      details.add('local wipe incomplete: $e');
    }

    // 4. Sign out last.
    try {
      await _client.auth.signOut();
    } catch (e) {
      details.add('signOut: $e');
    }

    return AccountDeletionResult(success: true, details: details);
  }

  Future<String?> _currentCoupleId() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return null;
      final row = await _client
          .from('couples')
          .select('id')
          .or('user_1.eq.$uid,user_2.eq.$uid')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Local wipe: cached media files → SQLite → secure-storage keys.
  /// Public so the Settings screen can also offer "clear local data".
  Future<void> wipeLocalData(String userId) async {
    if (!kIsWeb) {
      // Delete cached media files from disk before dropping the index.
      try {
        final media = await _cache?.listCachedMedia() ?? const [];
        for (final entry in media) {
          final path = entry['local_path'] as String?;
          if (path == null) continue;
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      } catch (e) {
        debugPrint('[AccountDeletion] media file wipe partial: $e');
      }
    }

    await _cache?.clearAll();

    // Device keypair + every couple key + escrow material on this device.
    await _crypto.deleteAllKeys(userId);
  }
}
