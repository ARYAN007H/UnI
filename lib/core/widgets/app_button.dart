import 'package:flutter/material.dart';

import '../theme/theme.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

/// The one button component (plan §4.2). Variants map to the theme's
/// pre-styled Material buttons; nothing visual is decided here beyond that
/// mapping + the loading state.
class AppButton extends StatelessWidget {
  final String label;
  final AppButtonVariant variant;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.variant = AppButtonVariant.primary,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = onPressed == null || loading;

    Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == AppButtonVariant.primary
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label),
      ],
    );

    switch (variant) {
      case AppButtonVariant.primary:
        child = FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
          ),
          child: child,
        );
      case AppButtonVariant.secondary:
        child = OutlinedButton(onPressed: disabled ? null : onPressed, child: child);
      case AppButtonVariant.ghost:
        child = TextButton(onPressed: disabled ? null : onPressed, child: child);
      case AppButtonVariant.destructive:
        child = FilledButton(
          onPressed: disabled ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: Colors.white,
          ),
          child: child,
        );
    }

    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}
