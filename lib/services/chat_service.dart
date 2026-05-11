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

/// Handles all chat-related data operations.
/// Uses a local-first architecture: SQLite cache for instant reads,
/// Supabase for sync and real-time.
class ChatService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  static const _uuid = Uuid();
  static const int _pageSize = 50;
  LocalCacheService? _cache;
  MediaService? _mediaService;

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

  // ── Random prompts ──────────────────────────────────────────
  final Random _random = Random();
  int _currentPromptIndex = 0;

  /// Initialize with couple ID and load channels.
  /// Accepts an optional LocalCacheService for offline-first support.
  Future<void> initialize(String coupleId, {LocalCacheService? cache, MediaService? mediaService}) async {
    _coupleId = coupleId;
    _cache = cache;
    _mediaService = mediaService;
    _currentPromptIndex = _random.nextInt(SupabaseConfig.conversationPrompts.length);
    await loadChannels();
    // Flush any offline queue
    _syncOfflineMessages();
  }

  /// Sync any messages that were saved locally but failed to send to Supabase.
  Future<void> _syncOfflineMessages() async {
    if (_cache == null) return;
    
    final unsynced = await _cache!.getUnsyncedMessages();
    if (unsynced.isEmpty) return;

    debugPrint('[ChatService] Syncing ${unsynced.length} offline messages...');
    
    for (final msg in unsynced) {
      try {
        await _client.from('messages').insert(msg.toInsertJson());
        await _cache!.markSynced(msg.id);
        debugPrint('[ChatService] Synced message ${msg.id}');
      } catch (e) {
        debugPrint('[ChatService] Failed to sync message ${msg.id}: $e');
        // Will retry on next init
      }
    }
  }

  /// Fetch channels — cache-first, then sync from server.
  Future<void> loadChannels() async {
    if (_coupleId == null) return;

    // 1. Load from cache instantly
    if (_cache != null) {
      final cached = await _cache!.getChannels(_coupleId!);
      if (cached.isNotEmpty) {
        _channels = cached;
        notifyListeners();
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
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading channels: $e');
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

    // Optimistic message
    final optimistic = Message(
      id: id,
      channelId: channelId,
      senderId: senderId,
      content: caption,
      type: type,
      mediaUrl: result.url,
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

    try {
      await _client.from('messages').insert(optimistic.toInsertJson());
    } catch (e) {
      _messagesByChannel[channelId]?.removeWhere((m) => m.id == id);
      notifyListeners();
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

            // Save to local cache
            _cache?.saveMessage(newMessage);

            // Auto-download media
            if (newMessage.mediaUrl != null) {
              _mediaService?.downloadMedia(newMessage.mediaUrl!);
            }

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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) {
            final updated = Message.fromJson(payload.newRecord);
            final messages = _messagesByChannel[channelId];
            if (messages == null) return;

            final idx = messages.indexWhere((m) => m.id == updated.id);
            if (idx != -1) {
              messages[idx] = updated;
              _cache?.saveMessage(updated);
              notifyListeners();
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'channel_id',
            value: channelId,
          ),
          callback: (payload) {
            final deletedId = payload.oldRecord['id'] as String?;
            if (deletedId == null) return;

            final messages = _messagesByChannel[channelId];
            if (messages == null) return;

            final idx = messages.indexWhere((m) => m.id == deletedId);
            if (idx != -1) {
              // Mark as deleted locally rather than removing
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
              _cache?.deleteMessage(deletedId);
              notifyListeners();
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
    if (_typingChannel == null) return;
    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': userId},
    );
  }

  // ── Read Receipts ──────────────────────────────────────────

  /// Mark messages as read by the current user.
  /// Uses a batch RPC call to avoid N+1 individual UPDATE queries.
  Future<void> markMessagesAsRead(String channelId, String userId) async {
    try {
      // Batch update via Postgres function
      await _client.rpc('batch_mark_read', params: {
        'p_channel_id': channelId,
        'p_user_id': userId,
      });

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
              mediaThumbnailUrl: messages[i].mediaThumbnailUrl,
              mediaDurationMs: messages[i].mediaDurationMs,
              mediaSizeBytes: messages[i].mediaSizeBytes,
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
    _messagesSubscription?.unsubscribe();
    _typingChannel?.unsubscribe();
    super.dispose();
  }
}
