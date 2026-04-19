import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Handles all chat-related data operations with Supabase.
class ChatService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();
  static const int _pageSize = 50;

  String? _coupleId;
  List<Channel> _channels = [];
  List<Channel> get channels => _channels;

  final Map<String, List<Message>> _messagesByChannel = {};
  List<Message> messagesForChannel(String channelId) =>
      _messagesByChannel[channelId] ?? [];

  String? _activeChannelId;
  String? get activeChannelId => _activeChannelId;

  // ── Realtime subscriptions ──────────────────────────────────
  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _typingChannel;

  // ── Typing state ────────────────────────────────────────────
  bool _partnerIsTyping = false;
  bool get partnerIsTyping => _partnerIsTyping;
  DateTime? _lastTypingEvent;

  /// Initialize with couple ID and load channels.
  Future<void> initialize(String coupleId) async {
    _coupleId = coupleId;
    await loadChannels();
  }

  /// Fetch all channels for the couple, sorted by position.
  Future<void> loadChannels() async {
    if (_coupleId == null) return;

    try {
      final data = await _client
          .from('channels')
          .select()
          .eq('couple_id', _coupleId!)
          .order('position');

      _channels = data.map((json) => Channel.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading channels: $e');
    }
  }

  /// Fetch paginated messages for a channel.
  Future<void> loadMessages(String channelId, {bool loadMore = false}) async {
    try {
      final existing = _messagesByChannel[channelId] ?? [];

      PostgrestFilterBuilder<List<Map<String, dynamic>>> filterQuery = _client
          .from('messages')
          .select()
          .eq('channel_id', channelId);

      if (loadMore && existing.isNotEmpty) {
        filterQuery = filterQuery.lt('created_at', existing.last.createdAt.toIso8601String());
      }

      final data = await filterQuery
          .order('created_at', ascending: false)
          .limit(_pageSize);
      final messages = data.map((json) => Message.fromJson(json)).toList();

      if (loadMore) {
        _messagesByChannel[channelId] = [...existing, ...messages];
      } else {
        _messagesByChannel[channelId] = messages;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading messages: $e');
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

    try {
      await _client.from('messages').insert(optimistic.toInsertJson());
    } catch (e) {
      // Remove the optimistic message on failure
      _messagesByChannel[channelId]?.removeWhere((m) => m.id == id);
      notifyListeners();
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Subscribe to real-time messages for a channel.
  void subscribeToMessages(String channelId) {
    _activeChannelId = channelId;

    // Unsubscribe from previous
    _messagesSubscription?.unsubscribe();

    _messagesSubscription = _client
        .channel('messages:$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) {
            final newMessage = Message.fromJson(payload.newRecord);
            final messages = _messagesByChannel[channelId] ?? [];

            // Don't add if already exists (optimistic insert)
            if (!messages.any((m) => m.id == newMessage.id)) {
              _messagesByChannel[channelId] = [newMessage, ...messages];
              notifyListeners();
            } else {
              // Replace optimistic with confirmed
              final idx = messages.indexWhere((m) => m.id == newMessage.id);
              if (idx != -1) {
                messages[idx] = newMessage;
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
  }

  /// Unsubscribe from current channel's messages.
  void unsubscribeFromMessages() {
    _messagesSubscription?.unsubscribe();
    _messagesSubscription = null;
    _activeChannelId = null;
  }

  // ── Typing Indicators ──────────────────────────────────────

  /// Subscribe to typing events for this couple.
  void subscribeToTyping(String coupleId, String myUserId) {
    _typingChannel?.unsubscribe();

    _typingChannel = _client
        .channel('typing:$coupleId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['user_id'] as String?;
            if (senderId != null && senderId != myUserId) {
              _partnerIsTyping = true;
              _lastTypingEvent = DateTime.now();
              notifyListeners();

              // Auto-clear after 3 seconds
              Future.delayed(const Duration(seconds: 3), () {
                if (_lastTypingEvent != null &&
                    DateTime.now().difference(_lastTypingEvent!).inSeconds >= 3) {
                  _partnerIsTyping = false;
                  notifyListeners();
                }
              });
            }
          },
        )
        .subscribe();
  }

  /// Send a typing indicator.
  void sendTypingEvent(String coupleId, String userId) {
    _client.channel('typing:$coupleId').sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': userId},
    );
  }

  // ── Read Receipts ──────────────────────────────────────────

  /// Mark messages as read by the current user.
  Future<void> markMessagesAsRead(String channelId, String userId) async {
    try {
      // Get unread messages in this channel
      final unread = await _client
          .from('messages')
          .select('id, read_by')
          .eq('channel_id', channelId)
          .not('read_by', 'cs', '{$userId}');

      for (final msg in unread) {
        final readBy = List<String>.from(msg['read_by'] as List? ?? []);
        if (!readBy.contains(userId)) {
          readBy.add(userId);
          await _client
              .from('messages')
              .update({'read_by': readBy}).eq('id', msg['id']);
        }
      }

      // Update local state
      final messages = _messagesByChannel[channelId];
      if (messages != null) {
        for (var i = 0; i < messages.length; i++) {
          if (!messages[i].readBy.contains(userId)) {
            final updatedReadBy = [...messages[i].readBy, userId];
            messages[i] = Message(
              id: messages[i].id,
              channelId: messages[i].channelId,
              senderId: messages[i].senderId,
              content: messages[i].content,
              type: messages[i].type,
              mediaUrl: messages[i].mediaUrl,
              replyTo: messages[i].replyTo,
              isEdited: messages[i].isEdited,
              isDeleted: messages[i].isDeleted,
              readBy: updatedReadBy,
              createdAt: messages[i].createdAt,
              updatedAt: messages[i].updatedAt,
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
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

  /// Delete a message.
  Future<void> deleteMessage(String messageId, String channelId) async {
    try {
      await _client
          .from('messages')
          .update({'is_deleted': true, 'content': null})
          .eq('id', messageId);

      final messages = _messagesByChannel[channelId];
      if (messages != null) {
        final idx = messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          messages[idx] = Message(
            id: messages[idx].id,
            channelId: messages[idx].channelId,
            senderId: messages[idx].senderId,
            content: null,
            type: messages[idx].type,
            isDeleted: true,
            readBy: messages[idx].readBy,
            createdAt: messages[idx].createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  /// Edit a message.
  Future<void> editMessage(String messageId, String channelId, String newContent) async {
    try {
      await _client.from('messages').update({
        'content': newContent,
        'is_edited': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);

      final messages = _messagesByChannel[channelId];
      if (messages != null) {
        final idx = messages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          messages[idx] = Message(
            id: messages[idx].id,
            channelId: messages[idx].channelId,
            senderId: messages[idx].senderId,
            content: newContent,
            type: messages[idx].type,
            isEdited: true,
            isDeleted: false,
            readBy: messages[idx].readBy,
            createdAt: messages[idx].createdAt,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error editing message: $e');
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _typingChannel?.unsubscribe();
    super.dispose();
  }
}
