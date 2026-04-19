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
        left: isMine ? 52 : 0,
        right: isMine ? 0 : 52,
      ),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && showAvatar)
            _partnerAvatar()
          else if (!isMine)
            const SizedBox(width: 34),
          const SizedBox(width: 6),
          Flexible(child: _buildBubble(context)),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms);
  }

  Widget _partnerAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppTheme.secondary.withValues(alpha: 0.3),
            AppTheme.primary.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.transparent,
        backgroundImage: partnerProfile?.avatarUrl != null
            ? NetworkImage(partnerProfile!.avatarUrl!)
            : null,
        child: partnerProfile?.avatarUrl == null
            ? Text(
                (partnerProfile?.displayName ?? 'P')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final time = DateFormat.jm().format(message.createdAt.toLocal());

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: isMine ? null : AppTheme.receivedBubbleColor,
          gradient: isMine ? AppTheme.sentBubbleGradient : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMine ? 20 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 20),
          ),
          border: Border.all(
            color: isMine
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurface,
                    height: 1.4,
                    fontSize: 15,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isEdited)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'edited',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _readStatus(),
                ],
                if (message.isPending) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.onSurfaceVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
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
      color: isRead
          ? AppTheme.secondary // Warm amber for read
          : AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
    );
  }

  Widget _buildDeleted(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment:
            isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded,
                  size: 14,
                  color: AppTheme.onSurfaceVariant
                      .withValues(alpha: 0.35)),
              const SizedBox(width: 6),
              Text(
                'Message deleted',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant
                      .withValues(alpha: 0.35),
                  fontStyle: FontStyle.italic,
                ),
              ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
                color: AppTheme.outline.withValues(alpha: 0.2)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (onReply != null)
                ListTile(
                  leading: Icon(Icons.reply_rounded,
                      color: AppTheme.onSurfaceVariant),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(ctx);
                    onReply!();
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ListTile(
                leading: Icon(Icons.copy_rounded,
                    color: AppTheme.onSurfaceVariant),
                title: const Text('Copy'),
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: message.content ?? ''));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')),
                  );
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              if (onDelete != null)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.primary),
                  title: Text('Delete',
                      style: TextStyle(color: AppTheme.primary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete!();
                  },
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              SizedBox(
                  height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}
