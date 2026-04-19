import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm Sunset V2 — Premium dark theme with coral, amber & rose-gold accents.
class AppTheme {
  AppTheme._();

  // ── Core Palette ──────────────────────────────────────────────
  static const Color _primary = Color(0xFFFF6B6B);           // Passionate coral
  static const Color _primaryLight = Color(0xFFFF8E8E);       // Soft coral
  static const Color _primaryDark = Color(0xFFCC4444);        // Deep coral
  static const Color _secondary = Color(0xFFFFAD5A);          // Golden amber
  static const Color _secondaryLight = Color(0xFFFFD4A8);     // Cream amber
  static const Color _tertiary = Color(0xFFFFD93D);           // Sunny gold
  static const Color _accent = Color(0xFFE8B4B8);             // Rose-gold
  static const Color _surface = Color(0xFF131118);            // Deep warm dark
  static const Color _surfaceContainer = Color(0xFF1C1A24);   // Elevated dark
  static const Color _surfaceContainerHigh = Color(0xFF262433);// Card bg
  static const Color _surfaceContainerHighest = Color(0xFF302E3E); // Higher
  static const Color _onSurface = Color(0xFFF5F0EB);          // Warm white
  static const Color _onSurfaceVariant = Color(0xFF9E97AB);   // Muted warm gray
  static const Color _outline = Color(0xFF3D3848);            // Warm outline
  static const Color _outlineVariant = Color(0xFF2A2635);     // Subtle outline
  static const Color _error = Color(0xFFFF6B6B);              // Coral error
  static const Color _success = Color(0xFF6BCB77);            // Warm green
  static const Color _sentBubble = Color(0xFF3D2028);         // Dark coral tint
  static const Color _receivedBubble = Color(0xFF1E1C28);     // Dark warm

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFFAD5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGlow = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E), Color(0xFFFFAD5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [Color(0xFF131118), Color(0xFF1C1A24)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sentBubbleGradient = LinearGradient(
    colors: [Color(0xFF4A2030), Color(0xFF3D2028)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient warmRadialGlow = RadialGradient(
    colors: [Color(0x22FF6B6B), Color(0x00FF6B6B)],
    radius: 0.8,
  );

  // ── Exposed Colors ─────────────────────────────────────────
  static Color get primary => _primary;
  static Color get primaryLight => _primaryLight;
  static Color get primaryDark => _primaryDark;
  static Color get secondary => _secondary;
  static Color get secondaryLight => _secondaryLight;
  static Color get tertiary => _tertiary;
  static Color get accent => _accent;
  static Color get surface => _surface;
  static Color get surfaceContainer => _surfaceContainer;
  static Color get surfaceContainerHigh => _surfaceContainerHigh;
  static Color get surfaceContainerHighest => _surfaceContainerHighest;
  static Color get onSurface => _onSurface;
  static Color get onSurfaceVariant => _onSurfaceVariant;
  static Color get outline => _outline;
  static Color get outlineVariant => _outlineVariant;
  static Color get sentBubbleColor => _sentBubble;
  static Color get receivedBubbleColor => _receivedBubble;
  static Color get success => _success;

  // ── Typography ─────────────────────────────────────────────
  static TextTheme get _textTheme {
    return GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.2),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.4),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      primaryContainer: _sentBubble,
      secondary: _secondary,
      secondaryContainer: const Color(0xFF3D3020),
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
        backgroundColor: _surface.withValues(alpha: 0.9),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          borderSide: BorderSide(color: _outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.6), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        hintStyle: TextStyle(color: _onSurfaceVariant.withValues(alpha: 0.5)),
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
        backgroundColor: _surfaceContainerHighest,
        contentTextStyle: GoogleFonts.inter(color: _onSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  /// Builds a warm glowing box decoration for cards.
  static BoxDecoration glassCard({
    double opacity = 0.6,
    double borderOpacity = 0.2,
    double radius = 20,
  }) {
    return BoxDecoration(
      color: _surfaceContainer.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _outline.withValues(alpha: borderOpacity)),
    );
  }

  /// Gradient button decoration.
  static BoxDecoration gradientButton({double radius = 16}) {
    return BoxDecoration(
      gradient: primaryGradient,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: _primary.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
