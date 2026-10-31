import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../models/models.dart';
import '../../services/moderation_service.dart';
import '../../services/realtime_service.dart';
import '../shell/home_shell.dart';
import '../us/media_viewer.dart';
import 'chat_viewmodel.dart';

/// Chat — "What did we say?" (docs/design/chat.md). One continuous
/// conversation, media strip on top, offline-safe composer.
class ChatScreen extends StatefulWidget {
  final ServiceBundle services;

  const ChatScreen({super.key, required this.services});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatViewModel _vm;
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = ChatViewModel(
      authService: widget.services.authService,
      chatService: widget.services.chatService,
      mediaService: widget.services.mediaService,
    );
    _vm.activate();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _vm.deactivate();
    _vm.dispose();
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 200) {
      _vm.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _vm,
        widget.services.chatService,
        RealtimeService.instance,
      ]),
      builder: (context, _) {
        final messages = _vm.messages;
        return Scaffold(
          appBar: _appBar(context),
          body: Column(
            children: [
              if (_vm.recentMedia.isNotEmpty) _mediaStrip(context),
              Expanded(child: _conversation(context, messages)),
              _composer(context),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final online = widget.services.presenceService.partnerOnline;
    final typing = widget.services.chatService.partnerIsTyping;
    final subtitle = typing
        ? 'typing…'
        : online
            ? 'online'
            : _vm.partnerName == 'Them'
                ? null
                : 'away';
    return AppAppBar(
      title: _vm.partnerName,
      bottom: subtitle != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(22),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: typing
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _mediaStrip(BuildContext context) {
    final media = _vm.recentMedia;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final m = media[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox(
              width: 64,
              child: BlurHashedImage(
                thumbnailUrl: m.mediaThumbnailUrl,
                loadImage: () async {
                  final path =
                      await widget.services.mediaService.downloadMedia(m.mediaUrl ?? '');
                  return fileImageFromPath(path);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _conversation(BuildContext context, List<Message> messages) {
    if (messages.isEmpty) {
      return const EmptyState(
        title: 'Your story starts here.',
        subtitle: "Say anything — it's just the two of you.",
      );
    }
    final myId = _vm.myId ?? '';
    final ordered = messages.reversed.toList(); // reverse list: index 0 = newest

    return NotificationListener<ScrollEndNotification>(
      onNotification: (n) {
        // Arriving at the far end of a reverse list = the oldest page.
        if (_scrollController.hasClients &&
            _scrollController.offset >=
                _scrollController.position.maxScrollExtent - 4) {
          _vm.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        itemCount: ordered.length,
        itemBuilder: (context, i) {
          final m = ordered[i];
          final mine = m.senderId == myId;
          final showDay = i == ordered.length - 1 ||
              !_sameDay(m.createdAt, ordered[i + 1].createdAt);
          return Column(
            children: [
              if (showDay) _daySeparator(context, m.createdAt),
              Bubble(
                message: m,
                mine: mine,
                myUserId: myId,
                partnerName: _vm.partnerName,
                repliedTo: _vm.messageById(m.replyTo),
                resolveMedia: (path) => widget.services.mediaService.downloadMedia(path),
                onLongPress: () => _messageActions(context, m, mine),
                onTap: (m.type == MessageType.image || m.type == MessageType.video)
                    ? () => _viewMedia(context, m)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _daySeparator(BuildContext context, DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              _dayLabel(date),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final reply = _vm.replyTo;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          children: [
            if (reply != null)
              Container(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 30,
                      color: Theme.of(context).colorScheme.primary,
                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Replying to ${reply.senderId == _vm.myId ? 'yourself' : _vm.partnerName}',
                              style: Theme.of(context).textTheme.labelSmall),
                          Text(
                            reply.content ?? 'Media',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _vm.setReply(null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_outlined),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: AppTextField(
                      hint: "Say anything…",
                      controller: _composerController,
                      maxLines: 4,
                      minLines: 1,
                      onChanged: _vm.onComposerChanged,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _composerController,
                    builder: (context, _) {
                      final hasText = _composerController.text.trim().isNotEmpty;
                      return IconButton.filled(
                        onPressed: hasText
                            ? () async {
                                final text = _composerController.text.trim();
                                _composerController.clear();
                                await _vm.send(text);
                              }
                            : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    final file = await widget.services.mediaService.pickImage();
    if (file == null || !mounted) return;
    try {
      await _vm.sendMedia(file, MessageType.image);
    } catch (_) {
      if (mounted) showAppToast(context, "Couldn't send — we'll retry when online.");
    }
  }

  Future<void> _messageActions(BuildContext context, Message m, bool mine) async {
    await showAppSheet<void>(
      context: context,
      children: [
        _actionTile(context, Icons.reply_rounded, 'Reply',
            () => _replyToMessage(m)),
        if (m.content != null && m.content!.isNotEmpty)
          _actionTile(context, Icons.copy_rounded, 'Copy', () => Navigator.of(context).pop()),
        if (mine && m.type == MessageType.text && !m.isDeleted)
          _actionTile(context, Icons.edit_outlined, 'Edit',
              () => _editDialog(context, m)),
        if (mine && !m.isDeleted)
          _actionTile(context, Icons.delete_outline_rounded, 'Delete',
              () => _deleteConfirm(context, m), destructive: true),
        // UGC compliance triad (Apple 1.2 / Play UGC): report + block on
        // the partner's content — server-enforced via agent2's policies.
        if (!mine && !m.isDeleted) ...[
          _actionTile(context, Icons.flag_outlined, 'Report message',
              () => _reportDialog(m)),
          _actionTile(context, Icons.block_rounded, 'Block partner',
              () => _blockConfirm(), destructive: true),
        ],
      ],
    );
  }

  Future<void> _reportDialog(Message m) async {
    Navigator.of(context).pop();
    if (!mounted) return;
    final reason = await showAppSheet<ReportReason>(
      context: context,
      title: 'Why are you reporting this?',
      children: [
        for (final r in ReportReason.values)
          ListTile(
            title: Text(switch (r) {
              ReportReason.harassment => 'Harassment or abuse',
              ReportReason.ncii => 'Intimate images shared without consent',
              ReportReason.minor => 'Someone underage',
              ReportReason.spam => 'Spam',
              ReportReason.other => 'Something else',
            }),
            onTap: () => Navigator.of(context).pop(r),
          ),
      ],
    );
    if (reason == null || !mounted) return;
    final me = _vm.myId;
    final partner = widget.services.authService.couple?.partnerId(me ?? '');
    if (me == null || partner == null) return;
    final ok = await ModerationService().report(
      reporterId: me,
      reportedUserId: partner,
      reason: reason,
      messageId: m.id,
    );
    if (mounted) {
      showAppToast(context,
          ok ? 'Reported. Thank you — it goes straight to the developer.' : "Couldn't report — try again.");
    }
  }

  Future<void> _blockConfirm() async {
    Navigator.of(context).pop();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block your partner?'),
        content: Text(
          'They will no longer be able to send you anything, and new '
          'messages from them are rejected on the server. This is meant '
          'for genuine safety situations — there is no undo from inside '
          'the app.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final me = _vm.myId;
    final partner = widget.services.authService.couple?.partnerId(me ?? '');
    if (me == null || partner == null) return;
    final ok = await ModerationService().blockUser(me, partner);
    if (mounted) {
      showAppToast(context,
          ok ? 'Blocked. They can no longer reach you here.' : "Couldn't block — try again.");
    }
  }

  Widget _actionTile(BuildContext context, IconData icon, String label, VoidCallback onTap,
      {bool destructive = false}) {
    return ListTile(
      leading: Icon(icon,
          color: destructive ? Theme.of(context).colorScheme.error : null),
      title: Text(label,
          style: TextStyle(
              color: destructive ? Theme.of(context).colorScheme.error : null)),
      onTap: onTap,
    );
  }

  void _replyToMessage(Message m) {
    Navigator.of(context).pop();
    _vm.setReply(m);
  }

  Future<void> _editDialog(BuildContext context, Message m) async {
    final controller = TextEditingController(text: m.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: AppTextField(controller: controller, maxLines: 3, minLines: 1, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) await _vm.edit(m, result);
  }

  Future<void> _deleteConfirm(BuildContext context, Message m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text("It disappears for both of you. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _vm.delete(m);
  }

  void _viewMedia(BuildContext context, Message m) {
    final items = _vm.recentMedia;
    final index = items.indexWhere((x) => x.id == m.id);
    Navigator.of(context).push(AppRouter.fadeThrough(
      MediaViewer(
        items: items,
        initialIndex: index < 0 ? 0 : index,
        mediaService: widget.services.mediaService,
      ),
    ));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}';
}
