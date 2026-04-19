import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/typing_indicator.dart';

class ChatScreen extends StatefulWidget {
  final Channel channel;
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;

  const ChatScreen({
    super.key,
    required this.channel,
    required this.authService,
    required this.chatService,
    required this.presenceService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _typingTimer;
  String? _replyToId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAndSubscribe();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadAndSubscribe() async {
    await widget.chatService.loadMessages(widget.channel.id);
    widget.chatService.subscribeToMessages(widget.channel.id);
    // Mark messages as read
    final uid = widget.authService.currentUser?.id;
    if (uid != null) {
      widget.chatService.markMessagesAsRead(widget.channel.id, uid);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      widget.chatService.loadMessages(widget.channel.id, loadMore: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.chatService.unsubscribeFromMessages();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && widget.authService.couple != null) {
      _typingTimer?.cancel();
      widget.chatService.sendTypingEvent(
        widget.authService.couple!.id,
        widget.authService.currentUser!.id,
      );
      _typingTimer = Timer(const Duration(seconds: 2), () {});
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    HapticFeedback.lightImpact();

    try {
      await widget.chatService.sendMessage(
        channelId: widget.channel.id,
        senderId: widget.authService.currentUser!.id,
        content: text,
        replyTo: _replyToId,
      );
      setState(() => _replyToId = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(widget.channel.icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${widget.channel.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ListenableBuilder(
                      listenable: widget.presenceService,
                      builder: (_, __) {
                        final online = widget.presenceService.partnerOnline;
                        return Text(
                          online ? '${widget.authService.partnerProfile?.displayName ?? "Partner"} is here' : widget.channel.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: online ? const Color(0xFF4ADE80) : AppTheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListenableBuilder(
      listenable: widget.chatService,
      builder: (context, _) {
        final messages = widget.chatService.messagesForChannel(widget.channel.id);
        final myId = widget.authService.currentUser!.id;

        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMine = msg.senderId == myId;
                        final showAvatar = !isMine && (index == messages.length - 1 || messages[index + 1].senderId != msg.senderId);

                        return MessageBubble(
                          message: msg,
                          isMine: isMine,
                          showAvatar: showAvatar,
                          partnerProfile: widget.authService.partnerProfile,
                          onReply: () => setState(() => _replyToId = msg.id),
                          onDelete: isMine ? () => widget.chatService.deleteMessage(msg.id, widget.channel.id) : null,
                        );
                      },
                    ),
            ),
            // Typing indicator
            ListenableBuilder(
              listenable: widget.chatService,
              builder: (_, __) {
                if (!widget.chatService.partnerIsTyping) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicatorWidget(name: widget.authService.partnerProfile?.displayName ?? 'Partner'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.channel.icon, style: const TextStyle(fontSize: 48))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1500.ms),
          const SizedBox(height: 16),
          Text('Start the conversation!', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Messages in #${widget.channel.name} will appear here', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6))),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: AppTheme.outline.withValues(alpha: 0.15))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview
          if (_replyToId != null) _buildReplyPreview(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onTextChanged,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Message #${widget.channel.name}',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  textInputAction: TextInputAction.send,
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppTheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 16, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text('Replying...', style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant))),
          GestureDetector(
            onTap: () => setState(() => _replyToId = null),
            child: Icon(Icons.close_rounded, size: 18, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _sendButton() {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _sendMessage,
          borderRadius: BorderRadius.circular(14),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
