import 'package:couple_chat/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Smoke tests for the Warm Editorial design system (plan §4).
/// Locks in the invariants other agents' UI depends on.

void main() {
  // google_fonts needs a binding and must not hit the network in tests —
  // it silently falls back to default fonts when runtime fetching is off.
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('CouplePalette', () {
    test('parses #RRGGBB', () {
      final p = CouplePalette.fromHex('#C4573B');
      expect(p.seed, const Color(0xFFC4573B));
    });

    test('parses bare RRGGBB and AARRGGBB', () {
      expect(CouplePalette.fromHex('C4573B').seed, const Color(0xFFC4573B));
      expect(CouplePalette.fromHex('#FFC4573B').seed, const Color(0xFFC4573B));
    });

    test('falls back to terracotta on garbage (never throws)', () {
      expect(CouplePalette.fromHex('not-a-color').seed,
          CouplePalette.fallback.seed);
      expect(CouplePalette.fromHex('').seed, CouplePalette.fallback.seed);
      expect(CouplePalette.fromHex('#12345').seed, CouplePalette.fallback.seed);
      expect(CouplePalette.fromHex(null).seed, CouplePalette.fallback.seed);
    });

    test('accent carries white text at AA contrast (≥ 4.5:1)', () {
      const white = Color(0xFFFFFFFF);
      for (final hex in [
        '#C4573B', // default terracotta
        '#FFD700', // very light seed — must be darkened
        '#1A1A2E', // very dark seed
        '#7B5CFF', // mid violet
        '#00FF00', // saturated neon
      ]) {
        final p = CouplePalette.fromHex(hex);
        final ratio = _contrast(p.accent, white);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: 'seed $hex → accent ${p.accent} contrast $ratio');
      }
    });

    test('very dark seeds are lifted so they stay visible on paper', () {
      final p = CouplePalette.fromHex('#0D0D0D');
      expect(p.seed.computeLuminance(), greaterThan(0.02));
    });
  });

  group('ColorTokens', () {
    test('light and dark sets differ on every core role', () {
      expect(ColorTokens.light.base, isNot(ColorTokens.dark.base));
      expect(ColorTokens.light.onSurface, isNot(ColorTokens.dark.onSurface));
      expect(ColorTokens.light.surface, isNot(ColorTokens.dark.surface));
    });

    test('of(brightness) maps correctly', () {
      expect(ColorTokens.of(Brightness.light), ColorTokens.light);
      expect(ColorTokens.of(Brightness.dark), ColorTokens.dark);
    });
  });

  group('AppTheme', () {
    test('builds light and dark ThemeData without throwing', () {
      final p = CouplePalette.fromHex('#C4573B');
      expect(() => AppTheme.light(p), returnsNormally);
      expect(() => AppTheme.dark(p), returnsNormally);
    });

    test('registers the UAndiThemeData extension on both themes', () {
      final p = CouplePalette.fromHex('#C4573B');
      for (final theme in [AppTheme.light(p), AppTheme.dark(p)]) {
        final ext = theme.extension<UAndiThemeData>();
        expect(ext, isNotNull);
        expect(ext!.sentBubble, isNot(ColorTokens.light.base));
      }
    });

    test('sent bubble differs per brightness (soft on paper, deep on dark)',
        () {
      final p = CouplePalette.fromHex('#C4573B');
      final lightExt = AppTheme.light(p).extension<UAndiThemeData>()!;
      final darkExt = AppTheme.dark(p).extension<UAndiThemeData>()!;
      expect(lightExt.sentBubble, isNot(darkExt.sentBubble));
    });
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
