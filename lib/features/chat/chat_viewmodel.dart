import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';

/// Thin state over ChatService for the Chat tab (docs/design/chat.md):
/// general channel focus, reply state, send/edit/delete, typing, paging.
class ChatViewModel extends ChangeNotifier {
  final AuthService authService;
  final ChatService chatService;
  final MediaService mediaService;

  Message? _replyTo;
  Message? get replyTo => _replyTo;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  ChatViewModel({
    required this.authService,
    required this.chatService,
    required this.mediaService,
  });

  String? get myId => authService.currentUser?.id;
  String? get coupleId => authService.couple?.id;
  String get partnerName => authService.partnerProfile?.displayName ?? 'Them';

  String? get channelId {
    for (final c in chatService.channels) {
      if (c.type == ChannelType.general) return c.id;
    }
    return chatService.channels.isEmpty ? null : chatService.channels.first.id;
  }

  List<Message> get messages {
    final id = channelId;
    if (id == null) return const [];
    return chatService.messagesForChannel(id);
  }

  /// Recent media for the strip above the conversation.
  List<Message> get recentMedia {
    return messages
        .where((m) => (m.type == MessageType.image || m.type == MessageType.video) && !m.isDeleted)
        .toList()
        .reversed
        .take(10)
        .toList();
  }

  void setReply(Message? message) {
    _replyTo = message;
    notifyListeners();
  }

  void activate() {
    final id = channelId;
    final me = myId;
    if (id != null && me != null) {
      chatService.setActiveChannel(id);
      chatService.markMessagesAsRead(id, me);
    }
  }

  void deactivate() => chatService.clearActiveChannel();

  void onComposerChanged(String text) {
    final cId = coupleId;
    final me = myId;
    if (cId != null && me != null && text.trim().isNotEmpty) {
      chatService.sendTypingEvent(cId, me);
    }
  }

  Future<bool> loadMore() async {
    final id = channelId;
    if (id == null || _loadingMore) return false;
    _loadingMore = true;
    notifyListeners();
    try {
      final hadBefore = messages.length;
      await chatService.loadMessages(id, loadMore: true);
      return messages.length > hadBefore;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final id = channelId;
    final me = myId;
    if (id == null || me == null || text.trim().isEmpty) return;
    final reply = _replyTo;
    _replyTo = null;
    notifyListeners();
    await chatService.sendMessage(
      channelId: id,
      senderId: me,
      content: text.trim(),
      replyTo: reply?.id,
    );
  }

  Future<void> sendMedia(XFile file, MessageType type, {String? caption}) async {
    final id = channelId;
    final me = myId;
    final cId = coupleId;
    if (id == null || me == null || cId == null) return;
    await chatService.sendMediaMessage(
      channelId: id,
      senderId: me,
      coupleId: cId,
      mediaService: mediaService,
      file: file,
      type: type,
      caption: caption,
    );
  }

  Future<void> edit(Message message, String newContent) async {
    final id = channelId;
    if (id == null || newContent.trim().isEmpty) return;
    await chatService.editMessage(message.id, id, newContent.trim());
  }

  Future<void> delete(Message message) async {
    final id = channelId;
    if (id == null) return;
    await chatService.deleteMessage(message.id, id);
  }

  Message? messageById(String? id) {
    if (id == null) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }
}
