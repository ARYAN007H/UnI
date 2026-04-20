import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/models.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMine;
  final bool showAvatar;
  final Profile? partnerProfile;
  final bool isVanillaMode;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showAvatar = false,
    this.partnerProfile,
    this.isVanillaMode = false,
    this.onReply,
    this.onDelete,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  late AnimationController _springController;
  double _dragOffset = 0.0;
  bool _willReply = false;
  final double _replyThreshold = 60.0;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController.unbounded(vsync: this);
    _springController.addListener(() {
      setState(() {
        _dragOffset = _springController.value;
      });
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onReply == null || widget.message.isDeleted) return;
    
    setState(() {
      double delta = details.delta.dx;
      // Dampen the drag the further it goes
      double friction = 1.0 - (_dragOffset.abs() / 200.0).clamp(0.0, 0.8);
      
      if (widget.isMine) {
        if (_dragOffset + delta < 0) {
          _dragOffset += delta * friction;
        }
      } else {
        if (_dragOffset + delta > 0) {
          _dragOffset += delta * friction;
        }
      }

      bool willReplyNow = _dragOffset.abs() > _replyThreshold;
      if (willReplyNow && !_willReply) {
        _willReply = true;
        HapticFeedback.heavyImpact();
      } else if (!willReplyNow && _willReply) {
        _willReply = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.onReply == null || widget.message.isDeleted) return;
    
    if (_willReply) {
      widget.onReply!();
      setState(() => _willReply = false);
    }

    final spring = const SpringDescription(
      mass: 1.0,
      stiffness: 400.0,
      damping: 18.0, // Underdamped for a little bounce
    );
    final simulation = SpringSimulation(spring, _dragOffset, 0, details.velocity.pixelsPerSecond.dx);
    _springController.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isDeleted) return _buildDeleted(context);

    Widget bubbleContent = Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: widget.isMine ? 52 : 0,
        right: widget.isMine ? 0 : 52,
      ),
      child: Row(
        mainAxisAlignment:
            widget.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMine && widget.showAvatar)
            _partnerAvatar()
          else if (!widget.isMine)
            const SizedBox(width: 34),
          const SizedBox(width: 6),
          Flexible(child: _buildBubble(context)),
        ],
      ),
    );

    // Apply Entry Animations
    if (!widget.isVanillaMode) {
      bubbleContent = bubbleContent
          .animate()
          .custom(
            duration: 500.ms,
            curve: Curves.elasticOut, // Liquid squish entry
            builder: (context, value, child) {
              // Scale from slightly stretched to normal
              final scaleY = 1.0 + (1.0 - value) * 0.2; // starts at 1.2, ends at 1.0
              final scaleX = 1.0 - (1.0 - value) * 0.1; // starts at 0.9, ends at 1.0
              return Transform.scale(
                scaleX: scaleX,
                scaleY: scaleY,
                alignment: widget.isMine ? Alignment.bottomRight : Alignment.bottomLeft,
                child: child,
              );
            },
          )
          .fadeIn(duration: 200.ms)
          .slideY(begin: 0.1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
    } else {
      // Vanilla animation
      bubbleContent = bubbleContent.animate().fadeIn(duration: 200.ms).slideY(begin: 0.05, end: 0, duration: 200.ms);
    }

    // Wrap with Swipe-to-Reply Gesture Handler
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Reply Icon revealed on drag
          if (_dragOffset.abs() > 5)
            Positioned(
              left: widget.isMine ? null : 16,
              right: widget.isMine ? 16 : null,
              child: AnimatedScale(
                scale: (_dragOffset.abs() / _replyThreshold).clamp(0.0, 1.2),
                duration: const Duration(milliseconds: 100),
                child: Icon(
                  Icons.reply_rounded,
                  color: _willReply ? AppTheme.primary : AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  size: 24,
                ),
              ),
            ),
          // Transform bubble by drag offset
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: bubbleContent,
          ),
        ],
      ),
    );
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
        backgroundImage: widget.partnerProfile?.avatarUrl != null
            ? NetworkImage(widget.partnerProfile!.avatarUrl!)
            : null,
        child: widget.partnerProfile?.avatarUrl == null
            ? Text(
                (widget.partnerProfile?.displayName ?? 'P')[0].toUpperCase(),
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
    final time = DateFormat.jm().format(widget.message.createdAt.toLocal());

    return GestureDetector(
      onLongPress: () => _showActions(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: widget.isMine ? null : AppTheme.receivedBubbleColor,
          gradient: widget.isMine ? AppTheme.sentBubbleGradient : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(widget.isMine ? 20 : 6),
            bottomRight: Radius.circular(widget.isMine ? 6 : 20),
          ),
          border: Border.all(
            color: widget.isMine
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              widget.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              widget.message.content ?? '',
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
                if (widget.message.isEdited)
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
                if (widget.isMine) ...[
                  const SizedBox(width: 4),
                  _readStatus(),
                ],
                if (widget.message.isPending) ...[
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
    final isRead = widget.message.readBy.length > 1;
    final icon = Icon(
      isRead ? Icons.done_all_rounded : Icons.done_rounded,
      size: 14,
      color: isRead
          ? AppTheme.secondary // Warm amber for read
          : AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
    );

    if (widget.isVanillaMode || !isRead) {
      return icon;
    }

    // Blooming effect for read receipts if not vanilla
    return icon
        .animate(key: ValueKey('read_${widget.message.id}'))
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }

  Widget _buildDeleted(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment:
            widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
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
              if (widget.onReply != null)
                ListTile(
                  leading: Icon(Icons.reply_rounded,
                      color: AppTheme.onSurfaceVariant),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onReply!();
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
                      ClipboardData(text: widget.message.content ?? ''));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!')),
                  );
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              if (widget.onDelete != null)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.primary),
                  title: Text('Delete',
                      style: TextStyle(color: AppTheme.primary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onDelete!();
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
