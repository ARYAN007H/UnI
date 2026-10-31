import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Quiet countdown pill (home.md / plans.md): accent-tinted, Inter label,
/// never alarm-red. Tap navigates to Plans.
class CountdownChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const CountdownChip({
    super.key,
    required this.label,
    this.icon = Icons.favorite_rounded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<UAndiThemeData>()!;
    return Material(
      color: ext.palette.containerFor(AppTheme.tokensOf(context)),
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.full),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
