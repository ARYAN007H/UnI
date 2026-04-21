import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

/// A row of quick-tap message buttons for sending common sweet messages.
class QuickActions extends StatelessWidget {
  final AuthService authService;
  final ChatService chatService;

  const QuickActions({
    super.key,
    required this.authService,
    required this.chatService,
  });

  static const List<_QuickAction> _actions = [
    _QuickAction(emoji: '❤️', label: 'Love', message: '❤️'),
    _QuickAction(emoji: '🤗', label: 'Hug', message: 'Sending you a big hug 🤗'),
    _QuickAction(emoji: '💭', label: 'Thinking', message: 'Thinking of you 💭'),
    _QuickAction(emoji: '😘', label: 'Kiss', message: '😘'),
    _QuickAction(emoji: '🌙', label: 'Night', message: 'Good night, sleep well 🌙💕'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'QUICK SEND',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _actions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final action = _actions[index];
                return _QuickActionButton(
                  action: action,
                  onTap: () => _sendQuickMessage(context, action.message),
                ).animate(delay: Duration(milliseconds: 50 * index))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.1, end: 0);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _sendQuickMessage(BuildContext context, String message) async {
    final generalChannel = chatService.generalChannel;
    final userId = authService.currentUser?.id;

    if (generalChannel == null || userId == null) return;

    HapticFeedback.lightImpact();

    try {
      await chatService.sendMessage(
        channelId: generalChannel.id,
        senderId: userId,
        content: message,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to #${generalChannel.name} 💕'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send. Try again.')),
        );
      }
    }
  }
}

class _QuickAction {
  final String emoji;
  final String label;
  final String message;

  const _QuickAction({
    required this.emoji,
    required this.label,
    required this.message,
  });
}

class _QuickActionButton extends StatefulWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionButton({required this.action, required this.onTap});

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.action.emoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 2),
              Text(
                widget.action.label,
                style: TextStyle(
                  fontSize: 9,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
