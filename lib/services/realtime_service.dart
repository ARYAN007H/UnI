import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

enum RealtimeMessageEventKind { insert, update, delete }

/// A change to the messages table, routed to the app.
/// For [RealtimeMessageEventKind.delete], [message] carries only a valid `id`
/// (Postgres DELETE payloads contain just the primary key).
class RealtimeMessageEvent {
  final RealtimeMessageEventKind kind;
  final Message message;

  const RealtimeMessageEvent(this.kind, this.message);
}

/// §7.3 — ONE realtime channel per couple.
///
/// DB changes (messages), broadcast (typing) and presence all ride a single
/// `couple:<id>` channel instead of the three channels v1 opened. Services
/// consume this via [messageEvents] and the presence/typing getters; the
/// public service APIs (PresenceService, ChatService) are unchanged.
///
/// Infrastructural singleton, like the Supabase client — it is never touched
/// by UI code directly.
class RealtimeService extends ChangeNotifier {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _channel;
  String? _coupleId;
  String? _myUserId;

  String? get coupleId => _coupleId;
  String? get myUserId => _myUserId;
  bool get isConnected => _channel != null;

  /// Fires every time the channel reaches `subscribed` (initial connect and
  /// every reconnect after the OS killed the socket). ChatService uses this
  /// as the outbox-drain + catch-up trigger.
  final _connected = StreamController<void>.broadcast();
  Stream<void> get connected => _connected.stream;

  // ── Presence state ─────────────────────────────────────────
  bool _partnerOnline = false;
  bool get partnerOnline => _partnerOnline;

  DateTime? _partnerLastSeen;
  DateTime? get partnerLastSeen => _partnerLastSeen;

  // ── Typing state ───────────────────────────────────────────
  bool _partnerIsTyping = false;
  bool get partnerIsTyping => _partnerIsTyping;

  Timer? _typingResetTimer;

  // ── Message events ─────────────────────────────────────────
  final _messageEvents = StreamController<RealtimeMessageEvent>.broadcast();
  Stream<RealtimeMessageEvent> get messageEvents => _messageEvents.stream;

  /// Idempotent. Reconnects only when the couple/user actually changed.
  Future<void> connect(String coupleId, String myUserId) async {
    if (_channel != null && _coupleId == coupleId && _myUserId == myUserId) {
      return;
    }
    await disconnect();
    _coupleId = coupleId;
    _myUserId = myUserId;

    final channel = _client.channel(
      'couple:$coupleId',
      opts: const RealtimeChannelConfig(self: false),
    );

    // One filtered postgres stream for the whole couple. couple_id is
    // server-derived on insert (migration 008), so the filter can't be
    // spoofed into another couple's stream. `all` expands to
    // insert + update + delete; payload.eventType tells them apart.
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'couple_id',
        value: coupleId,
      ),
      callback: _onPostgresChange,
    );

    channel.onBroadcast(event: 'typing', callback: (payload) {
      final senderId = payload['user_id'] as String?;
      if (senderId == null || senderId == _myUserId) return;
      _partnerIsTyping = true;
      notifyListeners();
      _typingResetTimer?.cancel();
      _typingResetTimer = Timer(const Duration(seconds: 3), () {
        _partnerIsTyping = false;
        notifyListeners();
      });
    });

    channel
      ..onPresenceSync((_) => _syncPresence())
      ..onPresenceJoin((_) => _syncPresence())
      ..onPresenceLeave((_) => _syncPresence());

    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track({
          'user_id': myUserId,
          'online_at': DateTime.now().toIso8601String(),
        });
        _syncPresence();
        _connected.add(null);
        notifyListeners();
      } else if (error != null) {
        debugPrint('[Realtime] subscribe error: $error');
      }
    });

    _channel = channel;
  }

  Future<void> disconnect() async {
    _typingResetTimer?.cancel();
    final ch = _channel;
    _channel = null;
    _partnerOnline = false;
    _partnerIsTyping = false;
    if (ch != null) {
      try {
        await ch.untrack();
      } catch (_) {}
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
    notifyListeners();
  }

  void _syncPresence() {
    final ch = _channel;
    if (ch == null) return;
    bool found = false;
    for (final sps in ch.presenceState()) {
      for (final p in sps.presences) {
        if (p.payload['user_id'] != _myUserId) {
          found = true;
          break;
        }
      }
      if (found) break;
    }
    _partnerOnline = found;
    if (!found) _partnerLastSeen = DateTime.now();
    notifyListeners();
  }

  void _onPostgresChange(PostgresChangePayload payload) {
    final event = payload.eventType;
    if (event == PostgresChangeEvent.delete) {
      final id = payload.oldRecord['id'] as String?;
      if (id == null) return;
      _messageEvents.add(RealtimeMessageEvent(
        RealtimeMessageEventKind.delete,
        Message(
          id: id,
          channelId: '',
          senderId: '',
          isDeleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ));
      return;
    }

    final message = Message.fromJson(payload.newRecord);
    _messageEvents.add(RealtimeMessageEvent(
      event == PostgresChangeEvent.insert
          ? RealtimeMessageEventKind.insert
          : RealtimeMessageEventKind.update,
      message,
    ));
  }

  void sendTyping() {
    final ch = _channel;
    if (ch == null || _myUserId == null) return;
    ch.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _myUserId},
    );
  }

  /// Generic broadcast for future ephemeral events (reactions, pings, ...).
  void broadcast(String event, Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null) return;
    ch.sendBroadcastMessage(event: event, payload: {
      'user_id': _myUserId,
      ...payload,
    });
  }

  @override
  void dispose() {
    _messageEvents.close();
    _connected.close();
    _typingResetTimer?.cancel();
    disconnect();
    super.dispose();
  }
}
