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
import '../../widgets/responsive_wrapper.dart';

/// Gallery-first photo experience for the #photos channel.
class PhotosScreen extends StatefulWidget {
  final Channel channel;
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;

  const PhotosScreen({super.key, required this.channel, required this.authService, required this.chatService, required this.presenceService});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final _captionController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.chatService.loadMessages(widget.channel.id);
    widget.chatService.subscribeToMessages(widget.channel.id);
  }

  @override
  void dispose() {
    widget.chatService.unsubscribeFromMessages();
    _captionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Message> get _allMessages => widget.chatService.messagesForChannel(widget.channel.id).where((m) => !m.isDeleted).toList();

  @override
  Widget build(BuildContext context) {
    final cc = AppTheme.colorsFor(ChannelType.photos);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.channelBgGradient(ChannelType.photos)),
        child: SafeArea(
          bottom: false,
          child: ResponsiveWrapper(
            maxWidth: 520,
            child: Column(children: [
              _appBar(cc),
              Expanded(child: _body(cc)),
              _inputBar(cc),
            ]),
          ),
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
          child: const Center(child: Text('📸', style: TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#photos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text('Your moments together', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.accent, fontSize: 12)),
        ])),
      ]),
    ),
  ));

  Widget _body(ChannelColors c) => ListenableBuilder(
    listenable: widget.chatService,
    builder: (context, _) {
      final messages = _allMessages;
      if (messages.isEmpty) return _emptyState(c);

      // Show messages as a gallery-style timeline
      return ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.all(12),
        itemCount: messages.length,
        itemBuilder: (context, i) {
          final msg = messages[i];
          final isMine = msg.senderId == widget.authService.currentUser!.id;
          return _photoBubble(msg, isMine, c).animate(delay: Duration(milliseconds: 40 * (i < 10 ? i : 0))).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
        },
      );
    },
  );

  Widget _photoBubble(Message msg, bool isMine, ChannelColors c) {
    final hasImage = msg.type == MessageType.image && msg.mediaUrl != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: isMine ? AppTheme.sentBubbleColor : AppTheme.receivedBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 6), bottomRight: Radius.circular(isMine ? 6 : 20),
            ),
            border: Border.all(color: c.accent.withValues(alpha: 0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    color: c.iconBg,
                    child: Icon(Icons.image_rounded, color: c.accent.withValues(alpha: 0.3), size: 48),
                  ),
                ),
              ),
            if (msg.content != null && msg.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(msg.content!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurface, fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!isMine) Padding(padding: const EdgeInsets.only(right: 4), child: Text('📸', style: const TextStyle(fontSize: 10))),
                    Text(_formatTime(msg.createdAt), style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
                  ]),
                ]),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: Text(_formatTime(msg.createdAt), style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
              ),
          ]),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.toLocal().hour; final m = dt.toLocal().minute;
    final ampm = h >= 12 ? 'PM' : 'AM'; final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }

  Widget _emptyState(ChannelColors c) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.accent.withValues(alpha: 0.1), c.gradientEnd.withValues(alpha: 0.05)]), shape: BoxShape.circle),
      child: const Center(child: Text('📸', style: TextStyle(fontSize: 36)))).animate(onPlay: (ctrl) => ctrl.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 2500.ms),
    const SizedBox(height: 20),
    Text('Share your moments', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
    const SizedBox(height: 6),
    Text('Photos & memories go here 📷✨', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
    const SizedBox(height: 20),
    Text('Send a photo description to get started!', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.accent.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
  ])).animate().fadeIn(duration: 600.ms);

  Widget _inputBar(ChannelColors c) => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.95), border: Border(top: BorderSide(color: c.accent.withValues(alpha: 0.06)))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Camera button
      Container(width: 48, height: 48, decoration: BoxDecoration(color: c.iconBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.accent.withValues(alpha: 0.15))),
        child: Material(color: Colors.transparent, child: InkWell(onTap: () { /* TODO: image picker */ }, borderRadius: BorderRadius.circular(16), child: Icon(Icons.camera_alt_rounded, color: c.accent, size: 22)))),
      const SizedBox(width: 8),
      Expanded(child: Container(decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.outlineVariant)),
        child: TextField(controller: _captionController, decoration: InputDecoration(hintText: 'Add a caption...', hintStyle: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), fontSize: 15), contentPadding: const EdgeInsets.fromLTRB(20, 12, 12, 12), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
          onSubmitted: (_) => _send(), textInputAction: TextInputAction.send, maxLines: 2, minLines: 1, style: TextStyle(color: AppTheme.onSurface, fontSize: 15)))),
      const SizedBox(width: 8),
      Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart, c.gradientEnd]), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))]),
        child: Material(color: Colors.transparent, child: InkWell(onTap: _send, borderRadius: BorderRadius.circular(16), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20)))),
    ]),
  );

  Future<void> _send() async {
    final text = _captionController.text.trim();
    if (text.isEmpty) return;
    _captionController.clear();
    HapticFeedback.lightImpact();
    try {
      await widget.chatService.sendMessage(channelId: widget.channel.id, senderId: widget.authService.currentUser!.id, content: text);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
