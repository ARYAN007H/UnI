import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tracks partner's online/offline status using Supabase Realtime Presence.
class PresenceService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _presenceChannel;

  bool _partnerOnline = false;
  bool get partnerOnline => _partnerOnline;

  DateTime? _partnerLastSeen;
  DateTime? get partnerLastSeen => _partnerLastSeen;

  /// Subscribe to presence for a couple.
  void subscribe(String coupleId, String myUserId) {
    _presenceChannel?.unsubscribe();

    _presenceChannel = _client.channel(
      'presence:$coupleId',
      opts: const RealtimeChannelConfig(self: true),
    );

    _presenceChannel!
        .onPresenceSync((payload) {
          final state = _presenceChannel!.presenceState();
          // Check if partner is in the presence list
          bool found = false;
          for (final sps in state) {
            for (final p in sps.presences) {
              if (p.payload['user_id'] != myUserId) {
                found = true;
                break;
              }
            }
          }
          _partnerOnline = found;
          if (!found) {
            _partnerLastSeen = DateTime.now();
          }
          notifyListeners();
        })
        .onPresenceJoin((payload) {
          final newPresences = payload.newPresences;
          for (final p in newPresences) {
            if (p.payload['user_id'] != myUserId) {
              _partnerOnline = true;
              notifyListeners();
              break;
            }
          }
        })
        .onPresenceLeave((payload) {
          final leftPresences = payload.leftPresences;
          for (final p in leftPresences) {
            if (p.payload['user_id'] != myUserId) {
              _partnerOnline = false;
              _partnerLastSeen = DateTime.now();
              notifyListeners();
              break;
            }
          }
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel!.track({
              'user_id': myUserId,
              'online_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

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
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}
