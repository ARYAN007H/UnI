import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';
import '../../services/presence_service.dart';
import '../../widgets/responsive_wrapper.dart';
import 'image_viewer_screen.dart';

/// Gallery-first photo experience for the #photos channel.
class PhotosScreen extends StatefulWidget {
  final Channel channel;
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;
  final MediaService mediaService;

  const PhotosScreen({
    super.key,
    required this.channel,
    required this.authService,
    required this.chatService,
    required this.presenceService,
    required this.mediaService,
  });

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final _captionController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  bool _showGrid = true; // Toggle between grid and timeline view

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

  List<Message> get _allMessages => widget.chatService
      .messagesForChannel(widget.channel.id)
      .where((m) => !m.isDeleted)
      .toList();

  List<Message> get _mediaMessages => _allMessages
      .where((m) =>
          (m.type == MessageType.image || m.type == MessageType.video) &&
          m.mediaUrl != null &&
          m.mediaUrl!.isNotEmpty)
      .toList();

  // ── Media Sending ──────────────────────────────────────────

  Future<void> _pickAndSendImage(ImageSource source) async {
    final file = await widget.mediaService.pickImage(source: source);
    if (file == null) return;

    final couple = widget.authService.couple;
    if (couple == null) return;

    final caption = _captionController.text.trim();
    _captionController.clear();

    setState(() => _isUploading = true);
    try {
      await widget.chatService.sendMediaMessage(
        channelId: widget.channel.id,
        senderId: widget.authService.currentUser!.id,
        coupleId: couple.id,
        mediaService: widget.mediaService,
        file: file,
        type: MessageType.image,
        caption: caption.isNotEmpty ? caption : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickMultipleAndSend() async {
    final files = await widget.mediaService.pickMultipleImages();
    if (files.isEmpty) return;

    final couple = widget.authService.couple;
    if (couple == null) return;

    setState(() => _isUploading = true);
    try {
      for (final file in files) {
        await widget.chatService.sendMediaMessage(
          channelId: widget.channel.id,
          senderId: widget.authService.currentUser!.id,
          coupleId: couple.id,
          mediaService: widget.mediaService,
          file: file,
          type: MessageType.image,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send photos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

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
              // Upload progress
              if (_isUploading)
                ListenableBuilder(
                  listenable: widget.mediaService,
                  builder: (_, __) => LinearProgressIndicator(
                    value: widget.mediaService.uploadProgress > 0
                        ? widget.mediaService.uploadProgress
                        : null,
                    backgroundColor: AppTheme.surfaceContainerHigh,
                    color: cc.accent,
                    minHeight: 3,
                  ),
                ),
              Expanded(child: _body(cc)),
              _inputBar(cc),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _appBar(ChannelColors c) => ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.85),
              border: Border(
                  bottom: BorderSide(color: c.accent.withValues(alpha: 0.08))),
            ),
            child: Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  color: AppTheme.onSurface,
                  onPressed: () => Navigator.pop(context)),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    c.gradientStart.withValues(alpha: 0.2),
                    c.gradientEnd.withValues(alpha: 0.1)
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Center(child: Text('📸', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#photos',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      ListenableBuilder(
                        listenable: widget.chatService,
                        builder: (_, __) {
                          final count = _mediaMessages.length;
                          return Text(
                            count > 0
                                ? '$count photo${count == 1 ? '' : 's'} shared'
                                : 'Your moments together',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: c.accent, fontSize: 12),
                          );
                        },
                      ),
                    ]),
              ),
              // View toggle
              IconButton(
                icon: Icon(
                  _showGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  color: AppTheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: () => setState(() => _showGrid = !_showGrid),
              ),
            ]),
          ),
        ),
      );

  Widget _body(ChannelColors c) => ListenableBuilder(
        listenable: widget.chatService,
        builder: (context, _) {
          final media = _mediaMessages;
          final allMsgs = _allMessages;

          if (allMsgs.isEmpty) return _emptyState(c);

          // Grid mode: show only media as a photo grid
          if (_showGrid && media.isNotEmpty) {
            return _buildPhotoGrid(media, c);
          }

          // Timeline mode: show all messages
          return ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: allMsgs.length,
            itemBuilder: (context, i) {
              final msg = allMsgs[i];
              final isMine = msg.senderId == widget.authService.currentUser!.id;
              return _photoBubble(msg, isMine, c)
                  .animate(
                      delay: Duration(
                          milliseconds: 40 * (i < 10 ? i : 0)))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0);
            },
          );
        },
      );

  Widget _buildPhotoGrid(List<Message> media, ChannelColors c) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: media.length,
      itemBuilder: (context, i) {
        final msg = media[i];
        final heroTag = 'photo_grid_${msg.id}';
        final isVideo = msg.type == MessageType.video;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => ImageViewerScreen(
                  imageUrl: msg.mediaUrl!,
                  caption: msg.content,
                  senderName: msg.senderId == widget.authService.currentUser!.id
                      ? 'You'
                      : widget.authService.partnerProfile?.displayName ?? 'Partner',
                  sentAt: msg.createdAt,
                  heroTag: heroTag,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    FadeTransition(opacity: anim, child: child),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          },
          child: Hero(
            tag: heroTag,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: msg.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: c.iconBg,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.accent.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: c.iconBg,
                    child: Icon(Icons.broken_image_rounded,
                        color: c.accent.withValues(alpha: 0.3), size: 24),
                  ),
                ),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: 30 * (i < 15 ? i : 0)))
            .fadeIn(duration: 250.ms)
            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 250.ms);
      },
    );
  }

  Widget _photoBubble(Message msg, bool isMine, ChannelColors c) {
    final hasImage = (msg.type == MessageType.image || msg.type == MessageType.video) &&
        msg.mediaUrl != null &&
        msg.mediaUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: hasImage
              ? () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      opaque: false,
                      pageBuilder: (_, __, ___) => ImageViewerScreen(
                        imageUrl: msg.mediaUrl!,
                        caption: msg.content,
                        senderName: isMine
                            ? 'You'
                            : widget.authService.partnerProfile?.displayName ?? 'Partner',
                        sentAt: msg.createdAt,
                        heroTag: 'photo_${msg.id}',
                      ),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                }
              : null,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: isMine ? AppTheme.sentBubbleColor : AppTheme.receivedBubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMine ? 20 : 6),
                bottomRight: Radius.circular(isMine ? 6 : 20),
              ),
              border: Border.all(color: c.accent.withValues(alpha: 0.08)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    Hero(
                      tag: 'photo_${msg.id}',
                      child: CachedNetworkImage(
                        imageUrl: msg.mediaUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Container(
                            color: c.iconBg,
                            child: Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.accent.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Container(
                            color: c.iconBg,
                            child: Icon(Icons.image_rounded,
                                color: c.accent.withValues(alpha: 0.3), size: 48),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.content != null && msg.content!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(msg.content!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppTheme.onSurface,
                                          fontSize: 15)),
                            ),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (!isMine)
                              Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text('📸',
                                      style: const TextStyle(fontSize: 10))),
                            Text(_formatTime(msg.createdAt),
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.onSurfaceVariant
                                        .withValues(alpha: 0.5))),
                          ]),
                        ]),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.toLocal().hour;
    final m = dt.toLocal().minute;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $ampm';
  }

  Widget _emptyState(ChannelColors c) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                c.accent.withValues(alpha: 0.1),
                c.gradientEnd.withValues(alpha: 0.05)
              ]),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('📸', style: TextStyle(fontSize: 36))),
          )
              .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
              .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.06, 1.06),
                  duration: 2500.ms),
          const SizedBox(height: 20),
          Text('Share your moments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Tap the camera to capture a memory together',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
          const SizedBox(height: 24),
          // Quick action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _quickActionChip(c, Icons.camera_alt_rounded, 'Take Photo', () {
                _pickAndSendImage(ImageSource.camera);
              }),
              const SizedBox(width: 12),
              _quickActionChip(c, Icons.photo_library_rounded, 'Gallery', () {
                _pickAndSendImage(ImageSource.gallery);
              }),
            ],
          ),
        ]),
      ).animate().fadeIn(duration: 600.ms);

  Widget _quickActionChip(
      ChannelColors c, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            c.gradientStart.withValues(alpha: 0.15),
            c.gradientEnd.withValues(alpha: 0.08),
          ]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c.accent, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: c.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _inputBar(ChannelColors c) => Container(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
        decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.95),
            border: Border(
                top: BorderSide(color: c.accent.withValues(alpha: 0.06)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // Camera button
          GestureDetector(
            onTap: () => _pickAndSendImage(ImageSource.camera),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: c.iconBg,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: c.accent.withValues(alpha: 0.15))),
              child: Icon(Icons.camera_alt_rounded, color: c.accent, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          // Gallery button
          GestureDetector(
            onTap: () => _pickMultipleAndSend(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: c.iconBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: c.accent.withValues(alpha: 0.1))),
              child: Icon(Icons.photo_library_rounded,
                  color: c.accent.withValues(alpha: 0.7), size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Container(
            decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.outlineVariant)),
            child: TextField(
              controller: _captionController,
              decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: TextStyle(
                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                      fontSize: 15),
                  contentPadding:
                      const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none),
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              maxLines: 2,
              minLines: 1,
              style: TextStyle(color: AppTheme.onSurface, fontSize: 15),
            ),
          )),
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [c.gradientStart, c.gradientEnd]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: c.accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 2))
                ]),
            child: Material(
                color: Colors.transparent,
                child: InkWell(
                    onTap: _send,
                    borderRadius: BorderRadius.circular(16),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20))),
          ),
        ]),
      );

  Future<void> _send() async {
    final text = _captionController.text.trim();
    if (text.isEmpty) return;
    _captionController.clear();
    HapticFeedback.lightImpact();
    try {
      await widget.chatService.sendMessage(
          channelId: widget.channel.id,
          senderId: widget.authService.currentUser!.id,
          content: text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
