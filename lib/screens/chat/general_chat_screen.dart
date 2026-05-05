import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';
import '../../services/presence_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/responsive_wrapper.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/voice_recorder.dart';

class GeneralChatScreen extends StatefulWidget {
  final Channel channel;
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;
  final MediaService mediaService;

  const GeneralChatScreen({
    super.key,
    required this.channel,
    required this.authService,
    required this.chatService,
    required this.presenceService,
    required this.mediaService,
  });

  @override
  State<GeneralChatScreen> createState() => _GeneralChatScreenState();
}

class _GeneralChatScreenState extends State<GeneralChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _typingTimer;
  String? _replyToId;
  bool _hasText = false;
  bool _isUploadingMedia = false;
  static const _quickEmojis = ['❤️', '🥰', '😘', '💕', '🔥', '😍', '🤗', '💋'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAndSubscribe();
    _scrollController.addListener(_onScroll);
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  Future<void> _loadAndSubscribe() async {
    await widget.chatService.loadMessages(widget.channel.id);
    widget.chatService.subscribeToMessages(widget.channel.id);
    final uid = widget.authService.currentUser?.id;
    if (uid != null) widget.chatService.markMessagesAsRead(widget.channel.id, uid);
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
      widget.chatService.sendTypingEvent(widget.authService.couple!.id, widget.authService.currentUser!.id);
      _typingTimer = Timer(const Duration(seconds: 2), () {});
    }
  }

  Future<void> _sendMessage([String? override]) async {
    final text = override ?? _controller.text.trim();
    if (text.isEmpty) return;
    if (override == null) _controller.clear();
    HapticFeedback.lightImpact();
    try {
      await widget.chatService.sendMessage(channelId: widget.channel.id, senderId: widget.authService.currentUser!.id, content: text, replyTo: _replyToId);
      setState(() => _replyToId = null);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // ── Media Sending ──────────────────────────────────────────

  Future<void> _pickAndSendImage(ImageSource source) async {
    final file = await widget.mediaService.pickImage(source: source);
    if (file == null) return;
    await _sendMediaFile(file, MessageType.image);
  }

  Future<void> _sendMediaFile(XFile file, MessageType type, {int? durationMs}) async {
    final couple = widget.authService.couple;
    if (couple == null) return;

    setState(() => _isUploadingMedia = true);
    try {
      await widget.chatService.sendMediaMessage(
        channelId: widget.channel.id,
        senderId: widget.authService.currentUser!.id,
        coupleId: couple.id,
        mediaService: widget.mediaService,
        file: file,
        type: type,
        caption: null,
        durationMs: durationMs,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send media: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _showAttachmentOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppTheme.outline.withValues(alpha: 0.2))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Send Media', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(ctx, Icons.photo_library_rounded, 'Gallery', AppTheme.secondary, () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.gallery);
                }),
                _attachOption(ctx, Icons.camera_alt_rounded, 'Camera', AppTheme.primary, () {
                  Navigator.pop(ctx);
                  _pickAndSendImage(ImageSource.camera);
                }),
                _attachOption(ctx, Icons.videocam_rounded, 'Video', AppTheme.tertiary, () async {
                  Navigator.pop(ctx);
                  final file = await widget.mediaService.pickVideo();
                  if (file != null) _sendMediaFile(file, MessageType.video);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(BuildContext ctx, IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cc = AppTheme.colorsFor(ChannelType.general);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.channelBgGradient(ChannelType.general)),
        child: SafeArea(
          bottom: false,
          child: ResponsiveWrapper(maxWidth: 520, child: Column(children: [
            _appBar(cc), Expanded(child: _messageList()), _quickReactions(cc), _inputBar(cc),
          ])),
        ),
      ),
    );
  }

  Widget _appBar(ChannelColors c) => ClipRRect(child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.85), border: Border(bottom: BorderSide(color: c.accent.withValues(alpha: 0.08)))),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), color: AppTheme.onSurface, onPressed: () => Navigator.pop(context)),
        Container(width: 38, height: 38, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart.withValues(alpha: 0.2), c.gradientEnd.withValues(alpha: 0.1)]), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(widget.channel.icon, style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#${widget.channel.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ListenableBuilder(listenable: widget.presenceService, builder: (_, __) {
            final online = widget.presenceService.partnerOnline;
            final name = widget.authService.partnerProfile?.displayName ?? 'Partner';
            return Row(children: [
              if (online) Container(width: 6, height: 6, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.4), blurRadius: 4)])),
              Expanded(child: Text(online ? '$name is here ✨' : 'Your cozy corner together', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: online ? AppTheme.success : AppTheme.onSurfaceVariant, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]);
          }),
        ])),
      ]),
    ),
  ));

  Widget _messageList() => ListenableBuilder(
    listenable: widget.chatService,
    builder: (context, _) {
      final messages = widget.chatService.messagesForChannel(widget.channel.id);
      final myId = widget.authService.currentUser!.id;
      return Column(children: [
        Expanded(child: messages.isEmpty ? _emptyState() : ListView.builder(
          controller: _scrollController, reverse: true, padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), itemCount: messages.length,
          itemBuilder: (context, i) {
            final msg = messages[i]; final isMine = msg.senderId == myId;
            final showDate = i == messages.length - 1 || !_isSameDay(msg.createdAt, messages[i + 1].createdAt);
            final showAvatar = !isMine && (i == messages.length - 1 || messages[i + 1].senderId != msg.senderId);
            return Column(children: [
              if (showDate) _dateSep(msg.createdAt),
              MessageBubble(message: msg, isMine: isMine, showAvatar: showAvatar, partnerProfile: widget.authService.partnerProfile, isVanillaMode: widget.authService.couple?.isVanillaMode ?? false, onReply: () => setState(() => _replyToId = msg.id), onDelete: isMine ? () => widget.chatService.deleteMessage(msg.id, widget.channel.id) : null),
            ]);
          },
        )),
        // Upload progress
        if (_isUploadingMedia)
          ListenableBuilder(
            listenable: widget.mediaService,
            builder: (_, __) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.mediaService.uploadProgress > 0 ? widget.mediaService.uploadProgress : null,
                  backgroundColor: AppTheme.surfaceContainerHigh,
                  color: AppTheme.primary,
                  minHeight: 3,
                ),
              ),
            ),
          ),
        ListenableBuilder(listenable: widget.chatService, builder: (_, __) {
          if (!widget.chatService.partnerIsTyping) return const SizedBox.shrink();
          return Padding(padding: const EdgeInsets.only(left: 16, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: TypingIndicatorWidget(name: widget.authService.partnerProfile?.displayName ?? 'Partner', isVanillaMode: widget.authService.couple?.isVanillaMode ?? false)));
        }),
      ]);
    },
  );

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _dateSep(DateTime date) {
    final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1)); final d = DateTime(date.year, date.month, date.day);
    final label = d == today ? 'Today' : d == yesterday ? 'Yesterday' : DateFormat.MMMd().format(date);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Row(children: [
      Expanded(child: Container(height: 0.5, color: AppTheme.outline.withValues(alpha: 0.15))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5), letterSpacing: 0.5))),
      Expanded(child: Container(height: 0.5, color: AppTheme.outline.withValues(alpha: 0.15))),
    ]));
  }

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.colorsFor(ChannelType.general).accent.withValues(alpha: 0.1), AppTheme.colorsFor(ChannelType.general).gradientEnd.withValues(alpha: 0.05)]), shape: BoxShape.circle), child: const Center(child: Text('💬', style: TextStyle(fontSize: 32)))).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 2000.ms),
    const SizedBox(height: 20),
    Text('Your cozy corner awaits', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
    const SizedBox(height: 6),
    Text('Say something sweet to start 💕', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
  ])).animate().fadeIn(duration: 600.ms);

  Widget _quickReactions(ChannelColors c) => Container(padding: const EdgeInsets.fromLTRB(12, 6, 12, 4), child: SizedBox(height: 36, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _quickEmojis.length, separatorBuilder: (_, __) => const SizedBox(width: 6), itemBuilder: (context, i) => GestureDetector(
    onTap: () => _sendMessage(_quickEmojis[i]),
    child: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.accent.withValues(alpha: 0.08))), child: Center(child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 16)))),
  ))));

  Widget _inputBar(ChannelColors c) => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.95), border: Border(top: BorderSide(color: c.accent.withValues(alpha: 0.06)))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (_replyToId != null) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: AppTheme.primary, width: 3))),
        child: Row(children: [Icon(Icons.reply_rounded, size: 16, color: AppTheme.primary.withValues(alpha: 0.6)), const SizedBox(width: 8), Expanded(child: Text('Replying...', style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant))), GestureDetector(onTap: () => setState(() => _replyToId = null), child: Icon(Icons.close_rounded, size: 18, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6)))])),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Attachment button
        GestureDetector(
          onTap: _showAttachmentOptions,
          child: Container(
            width: 42, height: 42,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_rounded, color: c.accent, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.outlineVariant)),
          child: TextField(controller: _controller, focusNode: _focusNode, onChanged: _onTextChanged, onSubmitted: (_) => _sendMessage(), decoration: InputDecoration(hintText: 'Type a love note...', hintStyle: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 15), contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none), textInputAction: TextInputAction.send, maxLines: 4, minLines: 1, style: TextStyle(color: AppTheme.onSurface, fontSize: 15)))),
        const SizedBox(width: 8),
        // Send or Voice record button
        if (_hasText)
          Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart, c.gradientEnd]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))]),
            child: Material(color: Colors.transparent, child: InkWell(onTap: () => _sendMessage(), borderRadius: BorderRadius.circular(16), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))))
        else
          VoiceRecorder(
            accentColor: c.accent,
            onRecordingComplete: (path, duration) {
              // TODO: Send voice message once recording is fully wired
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice recording coming soon!')),
              );
            },
          ),
      ]),
    ]),
  );
}
