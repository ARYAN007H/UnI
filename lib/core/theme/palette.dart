import 'package:flutter/material.dart';

import 'tokens.dart';

/// The couple's accent palette, derived from `couples.theme_color_hex`.
///
/// The seed is the one thing each couple personalizes; everything else
/// (contrast-safe accent, containers, sent bubbles) is derived so no couple
/// color can produce an unreadable UI. Mirrors the intent of the legacy
/// `AppTheme.initializeTheme`, but immutable and brightness-aware.
class CouplePalette {
  /// Contrast-adjusted accent — safe behind white or ink text.
  final Color accent;

  /// The raw seed exactly as the couple chose it (used for vivid moments:
  /// splash, presence dot, countdown heroes).
  final Color seed;

  /// Text/icon color that passes AA on top of [accent].
  final Color onAccent;

  const CouplePalette({
    required this.accent,
    required this.seed,
    required this.onAccent,
  });

  /// Default: terracotta (plan §4).
  static const CouplePalette fallback = CouplePalette(
    accent: Color(0xFFC4573B),
    seed: Color(0xFFC4573B),
    onAccent: Color(0xFFFFFFFF),
  );

  /// Parses `#RRGGBB` / `RRGGBB` / `#AARRGGBB`; falls back to terracotta on
  /// garbage input (never crashes, never renders unreadable).
  factory CouplePalette.fromHex(String? hex) {
    if (hex == null || hex.isEmpty) return fallback;
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return fallback;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return fallback;
    return CouplePalette.fromSeed(Color(parsed));
  }

  factory CouplePalette.fromSeed(Color seed) {
    var hsl = HSLColor.fromColor(seed);

    // Keep the accent in a band that can carry white text (AA ≥ 4.5:1) or,
    // for very light seeds, flip to ink text instead of crushing the hue.
    var accent = seed;
    var onAccent = const Color(0xFFFFFFFF);
    if (hsl.lightness > 0.62) {
      // Too light for white text — darken the accent, keep white text.
      hsl = hsl.withLightness(0.52);
      accent = hsl.toColor();
    } else {
      // Walk lightness down until white text passes AA on the accent.
      var candidate = seed;
      var lightness = hsl.lightness;
      while (lightness > 0.0 &&
          _contrastRatio(candidate, const Color(0xFFFFFFFF)) < 4.5) {
        lightness -= 0.04;
        candidate = hsl.withLightness(lightness).toColor();
      }
      accent = candidate;
    }

    // Very dark seeds get lifted slightly so they don't vanish on paper.
    final seedHsl = HSLColor.fromColor(seed);
    final adjustedSeed = seedHsl.lightness < 0.22
        ? seedHsl.withLightness(0.34).toColor()
        : seed;

    return CouplePalette(accent: accent, seed: adjustedSeed, onAccent: onAccent);
  }

  /// Soft accent-tinted surface for the given brightness — chips, avatars,
  /// light-theme sent bubbles, nav indicators.
  Color containerFor(ColorTokens tokens) =>
      Color.lerp(tokens.container, seed, 0.16)!;

  /// Sent-bubble color for the given brightness: soft tint on paper, deep
  /// accent shade on dark (candlelight keeps messages vivid).
  Color sentBubbleFor(ColorTokens tokens) {
    if (tokens == ColorTokens.dark) {
      final hsl = HSLColor.fromColor(seed);
      return hsl
          .withLightness((hsl.lightness * 0.42).clamp(0.16, 0.40))
          .withSaturation((hsl.saturation * 0.75).clamp(0.0, 0.55))
          .toColor();
    }
    return containerFor(tokens);
  }

  /// Text color for messages inside the sent bubble.
  Color onSentBubbleFor(ColorTokens tokens) =>
      tokens == ColorTokens.dark ? const Color(0xFFF1EAE1) : tokens.onSurface;

  /// WCAG relative-contrast ratio between two colors.
  static double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }
}
