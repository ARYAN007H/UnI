import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config/theme.dart';
import '../models/models.dart';
import '../services/presence_service.dart';

/// A warm, animated couple header showing both partners with a connecting heart.
class CoupleHeader extends StatelessWidget {
  final Profile? myProfile;
  final Profile? partnerProfile;
  final PresenceService presenceService;
  final int daysTogether;
  final bool isVanillaMode;

  const CoupleHeader({
    super.key,
    required this.myProfile,
    required this.partnerProfile,
    required this.presenceService,
    required this.daysTogether,
    this.isVanillaMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: presenceService,
      builder: (context, _) {
        final partnerOnline = presenceService.partnerOnline;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surfaceContainer.withValues(alpha: 0.8),
                AppTheme.primary.withValues(alpha: 0.04),
                AppTheme.surfaceContainer.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: partnerOnline
                  ? AppTheme.success.withValues(alpha: 0.15)
                  : AppTheme.outline.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.04),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatars with connecting heart
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatar(myProfile, true, partnerOnline: true),
                  const SizedBox(width: 8),
                  _buildConnectingHeart(),
                  const SizedBox(width: 8),
                  _buildAvatar(partnerProfile, false, partnerOnline: partnerOnline),
                ],
              ),
              const SizedBox(height: 14),
              // Partner status
              if (partnerProfile != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: partnerOnline
                            ? AppTheme.success
                            : AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                        boxShadow: partnerOnline
                            ? [
                                BoxShadow(
                                  color: AppTheme.success.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      partnerOnline
                          ? '${partnerProfile!.displayName} is here ✨'
                          : '${partnerProfile!.displayName} • ${_lastSeenText()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: partnerOnline
                                ? AppTheme.success
                                : AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              // Days together badge
              _buildDaysBadge(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(Profile? profile, bool isMe, {required bool partnerOnline}) {
    final isOnline = isMe || partnerOnline;
    final name = profile?.displayName ?? (isMe ? 'You' : 'Partner');

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isOnline
                    ? LinearGradient(
                        colors: [
                          AppTheme.primary.withValues(alpha: 0.7),
                          AppTheme.secondary.withValues(alpha: 0.5),
                        ],
                      )
                    : null,
                color: isOnline ? null : AppTheme.surfaceContainerHigh,
                border: isOnline
                    ? null
                    : Border.all(color: AppTheme.outline.withValues(alpha: 0.2)),
              ),
              padding: const EdgeInsets.all(2.5),
              child: CircleAvatar(
                radius: 27,
                backgroundColor: AppTheme.surfaceContainerHigh,
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(profile!.avatarUrl!)
                    : null,
                child: profile?.avatarUrl == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
            ),
            if (isOnline)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.surfaceContainer,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isMe ? 'You' : name.split(' ').first,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectingHeart() {
    Widget heart = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.favorite_rounded, size: 18, color: Colors.white),
    );

    if (!isVanillaMode) {
      heart = heart
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.1, 1.1),
            duration: 1200.ms,
            curve: Curves.easeInOutSine,
          );
    }

    return heart;
  }

  Widget _buildDaysBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.1),
            AppTheme.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            daysTogether == 0
                ? 'Just started your journey'
                : 'Together $daysTogether day${daysTogether == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  String _lastSeenText() {
    final lastSeen = presenceService.partnerLastSeen ?? partnerProfile?.lastSeen;
    if (lastSeen == null) return 'offline';
    return timeago.format(lastSeen);
  }
}

/// Floating heart particle for background ambiance.
class FloatingHeartsOverlay extends StatefulWidget {
  final int count;
  const FloatingHeartsOverlay({super.key, this.count = 5});

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_FloatingHeart> _hearts;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    final rng = Random();
    _hearts = List.generate(widget.count, (i) {
      return _FloatingHeart(
        x: rng.nextDouble(),
        startY: 0.6 + rng.nextDouble() * 0.4,
        size: 8.0 + rng.nextDouble() * 10,
        speed: 0.3 + rng.nextDouble() * 0.5,
        opacity: 0.04 + rng.nextDouble() * 0.06,
        phase: rng.nextDouble() * 2 * pi,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _HeartsPainter(_hearts, _controller.value),
        );
      },
    );
  }
}

class _FloatingHeart {
  final double x;
  final double startY;
  final double size;
  final double speed;
  final double opacity;
  final double phase;

  _FloatingHeart({
    required this.x,
    required this.startY,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _HeartsPainter extends CustomPainter {
  final List<_FloatingHeart> hearts;
  final double progress;

  _HeartsPainter(this.hearts, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final heart in hearts) {
      final y = (heart.startY - progress * heart.speed) % 1.2;
      if (y < -0.1) continue;
      final x = heart.x + sin(progress * 2 * pi + heart.phase) * 0.03;
      final paint = Paint()
        ..color = AppTheme.primary.withValues(alpha: heart.opacity);
      
      _drawHeart(canvas, Offset(x * size.width, y * size.height), heart.size, paint);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy + size * 0.3);
    path.cubicTo(
      center.dx - size * 0.5, center.dy - size * 0.1,
      center.dx - size * 0.5, center.dy - size * 0.5,
      center.dx, center.dy - size * 0.25,
    );
    path.cubicTo(
      center.dx + size * 0.5, center.dy - size * 0.5,
      center.dx + size * 0.5, center.dy - size * 0.1,
      center.dx, center.dy + size * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
