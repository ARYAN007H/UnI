import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

class TypingIndicatorWidget extends StatelessWidget {
  final String name;
  final bool isVanillaMode;

  const TypingIndicatorWidget({
    super.key,
    required this.name,
    this.isVanillaMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.receivedBubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$name is typing',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          isVanillaMode ? _buildDots() : _buildHeartbeat(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.secondary.withValues(alpha: 0.7),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.5, 1.5),
              duration: 600.ms,
              delay: Duration(milliseconds: i * 150),
              curve: Curves.easeInOut,
            )
            .fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: i * 150),
            );
      }),
    );
  }

  Widget _buildHeartbeat() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.secondary,
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondary.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    )
        .animate(
          onPlay: (c) => c.repeat(reverse: true),
        )
        // 60-70 BPM is approx 1 pulse every ~900ms.
        // We use an easeInOut curve for smooth systolic/diastolic feeling.
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.6, 1.6),
          duration: 450.ms,
          curve: Curves.easeInOutSine,
        )
        .fade(
          begin: 0.6,
          end: 1.0,
          duration: 450.ms,
        )
        .listen(
          callback: (value) {
            // value goes from 0 to 1 and back. Fire light haptic near peak (val > 0.95)
            // But doing it on every frame is bad, so we'd need a custom controller to fire exactly once per peak.
            // Since we're using a simple loop, we'll avoid spamming haptics here, but we can do it with a custom ticker if needed.
          },
        );
  }
}
