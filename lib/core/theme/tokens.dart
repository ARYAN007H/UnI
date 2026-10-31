import 'package:flutter/material.dart';

/// "Warm Editorial" design tokens — the single source of truth for the new UI.
///
/// Rule (plan §4.3): widgets and screens consume these via [AppTheme] /
/// `Theme.of(context)`. Never hardcode a color, radius, or duration in a
/// screen. One empty-state, one loading, one error pattern — enabled by
/// everyone reading from the same tokens.

/// Corner radii — one scale, nothing outside it.
abstract final class AppRadii {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999;
}

/// Spacing scale — margins, gaps, padding.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Motion durations — fast for micro, base for entrances, slow for heroes.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
}

/// The one curve everything moves on (plan §4: purposeful, calm).
abstract final class AppMotion {
  static const Curve emphasized = Curves.easeOutCubic;
}

/// Immutable color token set for one brightness.
///
/// "Paper" (light) is the default identity of the app; the dark set is warm —
/// candlelight, not a gaming rig (plan §4).
class ColorTokens {
  final Color base; // scaffold background
  final Color surface; // cards, sheets
  final Color container; // nested surfaces
  final Color containerHigh; // inputs, bubbles
  final Color containerHighest; // pressed/hover, strongest surface
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color success;
  final Color error;
  final Color warning;
  final Color receivedBubble;

  const ColorTokens({
    required this.base,
    required this.surface,
    required this.container,
    required this.containerHigh,
    required this.containerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.success,
    required this.error,
    required this.warning,
    required this.receivedBubble,
  });

  /// Light "paper" — cream base, ink text.
  static const ColorTokens light = ColorTokens(
    base: Color(0xFFFAF6F1),
    surface: Color(0xFFFFFDFA),
    container: Color(0xFFF6F0E8),
    containerHigh: Color(0xFFEFE7DC),
    containerHighest: Color(0xFFE5DBCD),
    onSurface: Color(0xFF1A1613),
    onSurfaceVariant: Color(0xFF6E655C),
    outline: Color(0xFFDDD2C4),
    outlineVariant: Color(0xFFEAE1D5),
    success: Color(0xFF3D7A4E),
    error: Color(0xFFB3402E),
    warning: Color(0xFF9A6B1F),
    receivedBubble: Color(0xFFF6F0E8),
  );

  /// Warm dark — warm greys, never pure black, never blue.
  static const ColorTokens dark = ColorTokens(
    base: Color(0xFF171412),
    surface: Color(0xFF1F1B18),
    container: Color(0xFF26211D),
    containerHigh: Color(0xFF2F2924),
    containerHighest: Color(0xFF3A332C),
    onSurface: Color(0xFFF1EAE1),
    onSurfaceVariant: Color(0xFFA89C8F),
    outline: Color(0xFF453D34),
    outlineVariant: Color(0xFF2E2823),
    success: Color(0xFF7FCC93),
    error: Color(0xFFF08A76),
    warning: Color(0xFFE5B567),
    receivedBubble: Color(0xFF26211D),
  );

  /// Tokens for a brightness — the only lookup screens are allowed to use.
  static ColorTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
