import 'package:flutter/material.dart';

/// Semantic text shortcuts over the Warm Editorial textTheme (plan §4).
///
/// Fraunces carries the emotional voice (display/headline); Inter does the
/// quiet work. Screens use these instead of raw `Text` so the type system
/// stays coherent.
abstract final class AppText {
  static Text display(BuildContext context, String text, {Color? color}) =>
      Text(text, style: Theme.of(context).textTheme.displayLarge?.copyWith(color: color));

  static Text headline(BuildContext context, String text, {Color? color}) =>
      Text(text, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color));

  static Text title(BuildContext context, String text, {Color? color}) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color));

  static Text body(BuildContext context, String text, {Color? color}) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color));

  static Text secondary(BuildContext context, String text, {Color? color}) =>
      Text(text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: color ?? Theme.of(context).colorScheme.onSurfaceVariant));

  static Text caption(BuildContext context, String text, {Color? color}) =>
      Text(text,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color ?? Theme.of(context).colorScheme.onSurfaceVariant));
}
