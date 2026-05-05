import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../models/models.dart';

/// A rich, visually distinct channel card with per-channel color identity.
class ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final String? previewText;
  final Widget? trailingWidget;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.previewText,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colorsFor(channel.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: colors.accent.withValues(alpha: 0.08),
          highlightColor: colors.accent.withValues(alpha: 0.04),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.channelCard(channel.type, radius: 24),
                child: Row(
                  children: [
                    // Accent bar
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors.gradientStart, colors.gradientEnd],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Channel icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.iconBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          channel.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Channel info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${channel.name}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            previewText ?? channel.description,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: previewText != null
                                      ? AppTheme.onSurfaceVariant.withValues(alpha: 0.8)
                                      : AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (trailingWidget != null) trailingWidget!,
                    if (trailingWidget == null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.accent.withValues(alpha: 0.4),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Unread count badge with glow effect
class UnreadBadge extends StatelessWidget {
  final int count;
  final Color color;

  const UnreadBadge({
    super.key,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ).animate().scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.elasticOut,
        );
  }
}
