import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The one loading pattern: bone-colored blocks matching the final layout
/// shapes. No spinners in content areas — spinners live in buttons and the
/// splash only (docs/design/README.md).
class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.sm)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.14),
        borderRadius: borderRadius,
      ),
    );
  }
}
