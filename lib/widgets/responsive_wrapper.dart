import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Wraps content in a centered, max-width container for responsive web layouts.
/// On mobile, content fills the screen normally. On desktop/tablet,
/// content is constrained and centered with an ambient background.
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > maxWidth + 80;

    final content = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    if (!isWide) return content;

    // Desktop/tablet: show centered card with subtle ambient styling
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          // Subtle side borders on desktop for visual separation
          border: Border.symmetric(
            vertical: BorderSide(
              color: AppTheme.outline.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
        ),
        child: content,
      ),
    );
  }
}
