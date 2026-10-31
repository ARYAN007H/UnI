import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The reasons accepted by the report flow (keep in sync with migration 011
/// docs + the Settings/report UI sheet).
enum ReportReason { harassment, ncii, minor, spam, other }

/// UGC compliance triad (Apple 1.2 / Play UGC policy): report, block, filter.
///
/// - Reports are write-only to clients (no SELECT policy — reviewed by the
///   developer in the Supabase dashboard).
/// - Blocks are enforced server-side: migration 011 re-issues the messages
///   INSERT policy so a blocked sender cannot deliver to their blocker even
///   with a hand-crafted client.
/// - [isBlocked] is the UI-side filter gate; the local mirror makes the
///   check instant and offline-correct after the first fetch.
class ModerationService extends ChangeNotifier {
  ModerationService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  /// Resolved lazily so pure-Dart unit tests can construct the service.
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  final Set<String> _blockedUserIds = {};
  bool _loaded = false;

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  /// Call once after sign-in; refreshes the local block mirror.
  Future<void> initialize(String myUserId) async {
    try {
      final rows = await _client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', myUserId);
      _blockedUserIds
        ..clear()
        ..addAll(rows.map((r) => r['blocked_id'] as String));
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[Moderation] block mirror fetch failed (offline?): $e');
    }
  }

  bool get initialized => _loaded;

  /// File a UGC report. Returns true when accepted server-side.
  Future<bool> report({
    required String reporterId,
    required String reportedUserId,
    required ReportReason reason,
    String? messageId,
    String? details,
  }) async {
    if (reportedUserId == reporterId) return false;
    try {
      await _client.from('reports').insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        if (messageId != null) 'message_id': messageId,
        'reason': reason.name,
        if (details != null && details.isNotEmpty) 'details': details,
      });
      return true;
    } catch (e) {
      debugPrint('[Moderation] report failed: $e');
      return false;
    }
  }

  /// Block a user (for a 2-person app: freezes the pair). Server-enforced —
  /// the sender's INSERT policy rejects new messages from the blocked side.
  Future<bool> blockUser(String myUserId, String userId) async {
    if (userId == myUserId) return false;
    try {
      await _client.from('blocks').upsert({
        'blocker_id': myUserId,
        'blocked_id': userId,
      }, onConflict: 'blocker_id,blocked_id');
      _blockedUserIds.add(userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Moderation] block failed: $e');
      return false;
    }
  }

  Future<bool> unblockUser(String myUserId, String userId) async {
    try {
      await _client.from('blocks').delete().match({
        'blocker_id': myUserId,
        'blocked_id': userId,
      });
      _blockedUserIds.remove(userId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[Moderation] unblock failed: $e');
      return false;
    }
  }
}
