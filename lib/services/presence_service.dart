import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'realtime_service.dart';

/// Tracks partner's online/offline status.
///
/// Public API unchanged from v1 — but the underlying presence now rides the
/// single shared couple channel ([RealtimeService], §7.3) instead of opening
/// its own. main.dart wiring does not need to change.
class PresenceService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool get partnerOnline => RealtimeService.instance.partnerOnline;

  DateTime? get partnerLastSeen => RealtimeService.instance.partnerLastSeen;

  /// Kept for wiring compatibility. Ensures the shared couple channel is up
  /// (idempotent) and forwards its state changes to this service's listeners.
  Future<void> subscribe(String coupleId, String myUserId) {
    RealtimeService.instance.addListener(_onRealtimeChanged);
    return RealtimeService.instance.connect(coupleId, myUserId);
  }

  void _onRealtimeChanged() => notifyListeners();

  /// Update online status in the profiles table.
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _client.from('profiles').update({
        'is_online': isOnline,
        if (!isOnline) 'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  @override
  void dispose() {
    RealtimeService.instance.removeListener(_onRealtimeChanged);
    super.dispose();
  }
}
