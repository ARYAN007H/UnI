import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The one card component: surface + hairline border + 16r (theme cardTheme
/// carries the visuals; this adds padding and tap behavior).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final shape = borderRadius != null
        ? RoundedRectangleBorder(borderRadius: borderRadius!)
        : null;

    return Card(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap != null
          ? InkWell(onTap: onTap, child: Padding(padding: padding, child: child))
          : Padding(padding: padding, child: child),
    );
  }
}
