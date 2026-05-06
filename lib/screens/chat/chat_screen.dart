import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
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
    final uid = widget.authService.currentUser?.id;
    if (uid != null) {
      widget.chatService.markMessagesAsRead(widget.channel.id, uid);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      widget.chatService
          .loadMessages(widget.channel.id, loadMore: true);
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
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMessageList(),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildAppBar(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInputBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), // Stronger Liquid Glass blur
        child: Container(
          padding: EdgeInsets.fromLTRB(4, MediaQuery.of(context).padding.top + 8, 16, 12),
          decoration: AppTheme.liquidGlass(
            opacity: 0.5,
            radius: 0,
            baseColor: AppTheme.surface,
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
                color: AppTheme.onSurface,
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Center(
                  child: Text(widget.channel.icon,
                      style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${widget.channel.name}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    ListenableBuilder(
                      listenable: widget.presenceService,
                      builder: (_, __) {
                        final online =
                            widget.presenceService.partnerOnline;
                        final partnerName = widget.authService
                                .partnerProfile?.displayName ??
                            'Partner';
                        return Row(
                          children: [
                            if (online)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.success
                                          .withValues(alpha: 0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: Text(
                                online
                                    ? '$partnerName is here'
                                    : widget.channel.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: online
                                          ? AppTheme.success
                                          : AppTheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
        final messages = widget.chatService
            .messagesForChannel(widget.channel.id);
        final myId = widget.authService.currentUser!.id;

        return Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: EdgeInsets.fromLTRB(12, 120, 12, MediaQuery.of(context).padding.top + 80),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMine = msg.senderId == myId;

                        // Date separator logic
                        final showDate = index == messages.length - 1 ||
                            !_isSameDay(
                              msg.createdAt,
                              messages[index + 1].createdAt,
                            );

                        final showAvatar = !isMine &&
                            (index == messages.length - 1 ||
                                messages[index + 1].senderId !=
                                    msg.senderId);

                        return Column(
                          children: [
                            if (showDate) _dateSeparator(msg.createdAt),
                            MessageBubble(
                              message: msg,
                              isMine: isMine,
                              showAvatar: showAvatar,
                              partnerProfile:
                                  widget.authService.partnerProfile,
                              isVanillaMode:
                                  widget.authService.couple?.isVanillaMode ?? false,
                              onReply: () =>
                                  setState(() => _replyToId = msg.id),
                              onDelete: isMine
                                  ? () => widget.chatService
                                      .deleteMessage(
                                          msg.id, widget.channel.id)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            // Typing indicator
            ListenableBuilder(
              listenable: widget.chatService,
              builder: (_, __) {
                if (!widget.chatService.partnerIsTyping) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TypingIndicatorWidget(
                      name: widget.authService.partnerProfile
                              ?.displayName ??
                          'Partner',
                      isVanillaMode:
                          widget.authService.couple?.isVanillaMode ?? false,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _dateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String label;
    if (msgDate == today) {
      label = 'Today';
    } else if (msgDate == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat.MMMd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: AppTheme.outline.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: AppTheme.outline.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(widget.channel.icon,
                  style: const TextStyle(fontSize: 32)),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                duration: 2000.ms,
              ),
          const SizedBox(height: 20),
          Text(
            'Start the conversation!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Send your first message in #${widget.channel.name}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildInputBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.liquidGlass(
              opacity: 0.5,
              radius: 32,
              baseColor: AppTheme.surfaceContainer,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview
          if (_replyToId != null) _buildReplyPreview(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerHigh
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: _onTextChanged,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: 'Type a love note...',
                            hintStyle: TextStyle(
                              color: AppTheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                              fontSize: 15,
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(
                                20, 12, 8, 12),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.send,
                          maxLines: 4,
                          minLines: 1,
                          style: TextStyle(
                            color: AppTheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            right: 4, bottom: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: AppTheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                            size: 22,
                          ),
                          onPressed: () {
                            // TODO: Emoji picker
                          },
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _sendButton(),
            ],
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: AppTheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply_rounded,
              size: 16, color: AppTheme.primary.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying...',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _replyToId = null),
            child: Icon(Icons.close_rounded,
                size: 18,
                color: AppTheme.onSurfaceVariant
                    .withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _sendButton() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _sendMessage,
          borderRadius: BorderRadius.circular(16),
          child:
              const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
