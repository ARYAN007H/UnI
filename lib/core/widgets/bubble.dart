import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../theme/theme.dart';
import 'blur_hashed_image.dart';

/// The one message bubble (chat.md): text / media / voice variants, mine vs
/// theirs from the couple palette, pending → read states, reply preview.
/// Media resolves through [resolveMedia] (mediaService.downloadMedia) so the
/// kit never touches services directly.
class Bubble extends StatelessWidget {
  final Message message;
  final bool mine;
  final String myUserId;
  final String partnerName;
  final Message? repliedTo;
  final Future<String?> Function(String path)? resolveMedia;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlayVoice;

  const Bubble({
    super.key,
    required this.message,
    required this.mine,
    required this.myUserId,
    this.partnerName = 'Them',
    this.repliedTo,
    this.resolveMedia,
    this.onLongPress,
    this.onTap,
    this.onPlayVoice,
  });

  bool get _pending => message.isPending;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<UAndiThemeData>()!;
    final t = ext.tokens;
    final bg = mine ? ext.sentBubble : t.receivedBubble;
    final fg = mine ? ext.onSentBubble : t.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onLongPress: onLongPress,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: message.type == MessageType.image || message.type == MessageType.video
              ? const EdgeInsets.all(4)
              : const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadii.lg),
              topRight: const Radius.circular(AppRadii.lg),
              bottomLeft: Radius.circular(mine ? AppRadii.lg : AppRadii.sm),
              bottomRight: Radius.circular(mine ? AppRadii.sm : AppRadii.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (repliedTo != null) _replyPreview(context, fg),
              if (message.isDeleted)
                _deleted(context, fg)
              else ..._body(context, fg),
              _meta(context, fg),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, Color fg) {
    switch (message.type) {
      case MessageType.image:
      case MessageType.video:
        return [_mediaBody(context)];
      case MessageType.voice:
        return [_voiceBody(context, fg)];
      case MessageType.plan:
        return [_textBody(context, fg, '📅 ${message.content ?? 'Plan'}')];
      case MessageType.system:
        return [_textBody(context, Theme.of(context).colorScheme.onSurfaceVariant, message.content ?? '')];
      default:
        return [_textBody(context, fg, message.content ?? '')];
    }
  }

  Widget _textBody(BuildContext context, Color fg, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: fg, height: 1.4),
      ),
    );
  }

  Widget _mediaBody(BuildContext context) {
    final isVideo = message.type == MessageType.video;
    return Stack(
      alignment: Alignment.center,
      children: [
        BlurHashedImage(
          thumbnailUrl: message.mediaThumbnailUrl,
          loadImage: () async {
            final path = await resolveMedia?.call(message.mediaUrl ?? '');
            return fileImageFromPath(path);
          },
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        if (isVideo)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
          ),
      ],
    );
  }

  Widget _voiceBody(BuildContext context, Color fg) {
    final duration = message.mediaDurationMs ?? 0;
    final seconds = (duration / 1000).round();
    // Static waveform hint — bars are decorative rhythm, not amplitude data.
    const barHeights = [8.0, 14.0, 20.0, 12.0, 24.0, 16.0, 10.0, 18.0, 22.0, 12.0, 8.0, 16.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPlayVoice,
          icon: Icon(
            Icons.play_arrow_rounded,
            color: onPlayVoice == null ? fg.withValues(alpha: 0.4) : fg,
          ),
          visualDensity: VisualDensity.compact,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final h in barHeights)
              Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('$seconds s', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
      ],
    );
  }

  Widget _replyPreview(BuildContext context, Color fg) {
    final wasMine = repliedTo!.senderId == myUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs, left: AppSpacing.xs, right: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border(
          left: BorderSide(color: fg.withValues(alpha: 0.5), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wasMine ? 'You' : partnerName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
          ),
          Text(
            repliedTo!.content ?? (repliedTo!.type == MessageType.image ? '📷 Photo' : 'Message'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _deleted(BuildContext context, Color fg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 14, color: fg.withValues(alpha: 0.6)),
          const SizedBox(width: AppSpacing.xs),
          Text('message deleted',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: fg.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _meta(BuildContext context, Color fg) {
    final state = _pending
        ? Icons.schedule_rounded
        : (mine && message.isReadBy(myUserId) ? Icons.done_all_rounded : null);
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: AppSpacing.xs, left: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEdited && !message.isDeleted)
            Text('edited · ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.55))),
          if (state != null) ...[
            Icon(state, size: 13, color: fg.withValues(alpha: _pending ? 0.55 : 0.75)),
            const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}
