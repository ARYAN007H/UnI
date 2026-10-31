import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'palette.dart';
import 'tokens.dart';

/// Builds the Material 3 [ThemeData] for the Warm Editorial system (plan §4).
///
/// Fraunces carries the emotional voice (display + headlines, names, dates);
/// Inter does the quiet work. Both themes come from the same tokens so light
/// and dark differ only in color, never in layout or type.
abstract final class AppTheme {
  /// Light "paper" theme — the default identity of the app.
  static ThemeData light(CouplePalette palette) =>
      _build(ColorTokens.light, palette, Brightness.light);

  /// Warm dark theme.
  static ThemeData dark(CouplePalette palette) =>
      _build(ColorTokens.dark, palette, Brightness.dark);

  /// Token lookup for widgets that need raw tokens beyond ColorScheme.
  static ColorTokens tokensOf(BuildContext context) =>
      ColorTokens.of(Theme.of(context).brightness);

  static ThemeData _build(
    ColorTokens t,
    CouplePalette p,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final sentBubble = p.sentBubbleFor(t);
    final accentContainer = p.containerFor(t);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: accentContainer,
      onPrimaryContainer: isDark ? t.onSurface : p.accent,
      secondary: p.seed,
      onSecondary: p.onAccent,
      secondaryContainer: accentContainer,
      onSecondaryContainer: isDark ? t.onSurface : p.accent,
      tertiary: p.seed,
      onTertiary: p.onAccent,
      surface: t.surface,
      onSurface: t.onSurface,
      surfaceContainerHighest: t.containerHighest,
      onSurfaceVariant: t.onSurfaceVariant,
      outline: t.outline,
      outlineVariant: t.outlineVariant,
      error: t.error,
      onError: Colors.white,
      scrim: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.base,
      textTheme: _textTheme(t, isDark),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: t.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.md,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: t.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: t.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.containerHigh,
        hintStyle: TextStyle(color: t.onSurfaceVariant.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md + 2,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: t.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: t.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentContainer,
          foregroundColor: isDark ? t.onSurface : p.accent,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.onSurface,
          side: BorderSide(color: t.outline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: accentContainer,
        height: 64,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? (isDark ? t.onSurface : p.accent)
                : t.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? t.onSurface
                : t.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        modalBackgroundColor: t.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: t.outline,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: t.onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: t.onSurfaceVariant,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.containerHighest,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: t.onSurface),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: DividerThemeData(color: t.outlineVariant, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: t.container,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 12, color: t.onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: t.containerHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onAccent
              : t.containerHighest,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.accent
              : t.outline,
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        UAndiThemeData(
          tokens: t,
          palette: p,
          sentBubble: sentBubble,
          onSentBubble: p.onSentBubbleFor(t),
        ),
      ],
    );
  }

  static TextTheme _textTheme(ColorTokens t, bool isDark) {
    final ink = t.onSurface;
    final inter = GoogleFonts.interTextTheme().copyWith(
      titleLarge: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600, color: ink),
      titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: ink),
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, height: 1.5, color: ink),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, height: 1.5, color: ink),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, height: 1.45, color: t.onSurfaceVariant),
      labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: ink),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: t.onSurfaceVariant),
      labelSmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w500,
          letterSpacing: 0.4, color: t.onSurfaceVariant),
    );

    // Fraunces takes the emotional voice: display + headlines only.
    return inter.copyWith(
      displayLarge: GoogleFonts.fraunces(
          fontSize: 36, fontWeight: FontWeight.w600,
          letterSpacing: -0.5, height: 1.15, color: ink),
      displayMedium: GoogleFonts.fraunces(
          fontSize: 28, fontWeight: FontWeight.w600,
          letterSpacing: -0.3, height: 1.2, color: ink),
      headlineLarge: GoogleFonts.fraunces(
          fontSize: 24, fontWeight: FontWeight.w600, height: 1.25, color: ink),
      headlineMedium: GoogleFonts.fraunces(
          fontSize: 21, fontWeight: FontWeight.w600, height: 1.25, color: ink),
    );
  }
}

/// Non-standard tokens that don't fit [ColorScheme]: the raw [ColorTokens],
/// the [CouplePalette], and message-bubble colors. Access via
/// `Theme.of(context).extension<UAndiThemeData>()!`.
class UAndiThemeData extends ThemeExtension<UAndiThemeData> {
  final ColorTokens tokens;
  final CouplePalette palette;
  final Color sentBubble;
  final Color onSentBubble;

  const UAndiThemeData({
    required this.tokens,
    required this.palette,
    required this.sentBubble,
    required this.onSentBubble,
  });

  @override
  UAndiThemeData copyWith({
    ColorTokens? tokens,
    CouplePalette? palette,
    Color? sentBubble,
    Color? onSentBubble,
  }) =>
      UAndiThemeData(
        tokens: tokens ?? this.tokens,
        palette: palette ?? this.palette,
        sentBubble: sentBubble ?? this.sentBubble,
        onSentBubble: onSentBubble ?? this.onSentBubble,
      );

  @override
  UAndiThemeData lerp(UAndiThemeData? other, double t) {
    if (other == null) return this;
    return UAndiThemeData(
      tokens: other.tokens,
      palette: other.palette,
      sentBubble: Color.lerp(sentBubble, other.sentBubble, t)!,
      onSentBubble: Color.lerp(onSentBubble, other.onSentBubble, t)!,
    );
  }
}
