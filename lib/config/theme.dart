import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Color Palette ──────────────────────────────────────────
  static const Color _primary = Color(0xFFAA8BFF);       // Soft violet
  static const Color _primaryContainer = Color(0xFF2D1F5E);
  static const Color _secondary = Color(0xFFFF6B9D);     // Warm rose
  static const Color _secondaryContainer = Color(0xFF4A1A2E);
  static const Color _tertiary = Color(0xFF64DFDF);      // Mint accent
  static const Color _surface = Color(0xFF0F0F1A);       // Deep dark
  static const Color _surfaceContainer = Color(0xFF1A1A2E);
  static const Color _surfaceContainerHigh = Color(0xFF242440);
  static const Color _onSurface = Color(0xFFE8E6F0);
  static const Color _onSurfaceVariant = Color(0xFF9996A8);
  static const Color _outline = Color(0xFF3D3A4E);
  static const Color _error = Color(0xFFFF6B6B);
  static const Color _sentBubble = Color(0xFF2D1F5E);
  static const Color _receivedBubble = Color(0xFF1E1E36);

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFAA8BFF), Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Exposed Colors ─────────────────────────────────────────
  static Color get primary => _primary;
  static Color get secondary => _secondary;
  static Color get tertiary => _tertiary;
  static Color get surface => _surface;
  static Color get surfaceContainer => _surfaceContainer;
  static Color get onSurface => _onSurface;
  static Color get onSurfaceVariant => _onSurfaceVariant;
  static Color get sentBubbleColor => _sentBubble;
  static Color get receivedBubbleColor => _receivedBubble;
  static Color get outline => _outline;

  // ── Typography ─────────────────────────────────────────────
  static TextTheme get _textTheme {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      primaryContainer: _primaryContainer,
      secondary: _secondary,
      secondaryContainer: _secondaryContainer,
      tertiary: _tertiary,
      surface: _surface,
      surfaceContainer: _surfaceContainer,
      surfaceContainerHigh: _surfaceContainerHigh,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceVariant,
      outline: _outline,
      error: _error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: _textTheme.apply(
        bodyColor: _onSurface,
        displayColor: _onSurface,
      ),
      scaffoldBackgroundColor: _surface,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface.withValues(alpha: 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: _primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: TextStyle(color: _onSurfaceVariant.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surfaceContainer,
        selectedItemColor: _primary,
        unselectedItemColor: _onSurfaceVariant,
      ),
      dividerTheme: DividerThemeData(
        color: _outline.withValues(alpha: 0.3),
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceContainerHigh,
        contentTextStyle: GoogleFonts.inter(color: _onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
