import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/models.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool showAvatar;
  final Profile? partnerProfile;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showAvatar = false,
    this.partnerProfile,
    this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _buildDeleted(context);

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && showAvatar)
            _partnerAvatar()
          else if (!isMine)
            const SizedBox(width: 32),
          const SizedBox(width: 6),
          Flexible(child: _buildBubble(context)),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.1, end: 0, duration: 250.ms);
  }

  Widget _partnerAvatar() {
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppTheme.secondary.withValues(alpha: 0.2),
      backgroundImage: partnerProfile?.avatarUrl != null
          ? NetworkImage(partnerProfile!.avatarUrl!)
          : null,
      child: partnerProfile?.avatarUrl == null
          ? Text(
              (partnerProfile?.displayName ?? 'P')[0].toUpperCase(),
              style: TextStyle(fontSize: 11, color: AppTheme.secondary, fontWeight: FontWeight.w700),
            )
          : null,
    );
  }

  Widget _buildBubble(BuildContext context) {
    final time = DateFormat.jm().format(message.createdAt.toLocal());
    final bubbleColor = isMine ? AppTheme.sentBubbleColor : AppTheme.receivedBubbleColor;

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
          border: Border.all(
            color: (isMine ? AppTheme.primary : AppTheme.outline).withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurface,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('edited', style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5), fontStyle: FontStyle.italic)),
                  ),
                Text(time, style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6))),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _readStatus(),
                ],
                if (message.isPending) ...[
                  const SizedBox(width: 4),
                  SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _readStatus() {
    final isRead = message.readBy.length > 1;
    return Icon(
      isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 14,
      color: isRead ? const Color(0xFF64DFDF) : AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildDeleted(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded, size: 14, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text('Message deleted', style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4), fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Reply'),
                onTap: () { Navigator.pop(ctx); onReply!(); },
              ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () { Navigator.pop(ctx); onDelete!(); },
              ),
          ],
        ),
      ),
    );
  }
}
