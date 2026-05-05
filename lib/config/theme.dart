import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';

/// Dynamic Theme System — Vibe Coding V2
class AppTheme {
  AppTheme._();

  // Default seed color (Passionate Coral)
  static Color _seed = const Color(0xFFFF6B6B);

  // ── Mutable Palette ──────────────────────────────────────────────
  static Color _primary = _seed;
  static Color _primaryLight = _seed.withValues(alpha: 0.8);
  static Color _primaryDark = _seed.withValues(alpha: 1.0); // We will compute this
  static Color _secondary = const Color(0xFFFFAD5A);
  static Color _secondaryLight = const Color(0xFFFFD4A8);
  static Color _tertiary = const Color(0xFFFFD93D);
  static const Color _accent = Color(0xFFE8B4B8);
  static Color _sentBubble = const Color(0xFF3D2028);
  
  // Static Core - Liquid Expressive OLED Base
  static const Color _surface = Color(0xFF000000);
  static const Color _surfaceContainer = Color(0xFF0A0A0C);
  static const Color _surfaceContainerHigh = Color(0xFF141418);
  static const Color _surfaceContainerHighest = Color(0xFF1C1C22);
  static const Color _onSurface = Color(0xFFF5F0EB);
  static const Color _onSurfaceVariant = Color(0xFF9E97AB);
  static const Color _outline = Color(0xFF333333);
  static const Color _outlineVariant = Color(0xFF1F1F1F);
  static const Color _error = Color(0xFFFF6B6B);
  static const Color _success = Color(0xFF6BCB77);
  static const Color _receivedBubble = Color(0xFF141418);

  // ── Per-Channel Color Palettes ────────────────────────────────
  static const Map<ChannelType, ChannelColors> channelPalettes = {
    ChannelType.general: ChannelColors(
      accent: Color(0xFFFF6B8A),
      accentLight: Color(0xFFFF8FA8),
      gradientStart: Color(0xFFFF6B8A),
      gradientEnd: Color(0xFFFF9E6B),
      bgTint: Color(0xFF2D1520),
      iconBg: Color(0xFF3D1828),
    ),
    ChannelType.photos: ChannelColors(
      accent: Color(0xFFFFB347),
      accentLight: Color(0xFFFFD080),
      gradientStart: Color(0xFFFFB347),
      gradientEnd: Color(0xFFFF8B60),
      bgTint: Color(0xFF2D2215),
      iconBg: Color(0xFF3D2D18),
    ),
    ChannelType.plans: ChannelColors(
      accent: Color(0xFF4ECDC4),
      accentLight: Color(0xFF7EDDD7),
      gradientStart: Color(0xFF4ECDC4),
      gradientEnd: Color(0xFF44B09E),
      bgTint: Color(0xFF152D2A),
      iconBg: Color(0xFF183D38),
    ),
    ChannelType.random: ChannelColors(
      accent: Color(0xFFB06CED),
      accentLight: Color(0xFFCB92FF),
      gradientStart: Color(0xFFB06CED),
      gradientEnd: Color(0xFF7B5CFF),
      bgTint: Color(0xFF20152D),
      iconBg: Color(0xFF2B183D),
    ),
    ChannelType.custom: ChannelColors(
      accent: Color(0xFF9E97AB),
      accentLight: Color(0xFFB8B2C2),
      gradientStart: Color(0xFF9E97AB),
      gradientEnd: Color(0xFF7A7388),
      bgTint: Color(0xFF1E1C28),
      iconBg: Color(0xFF262433),
    ),
  };

  /// Get the color palette for a channel type
  static ChannelColors colorsFor(ChannelType type) {
    return channelPalettes[type] ?? channelPalettes[ChannelType.custom]!;
  }

  // ── Initialization / Theming Engine ───────────────────────
  static void initializeTheme(String hexColor) {
    if (hexColor.isEmpty) return;
    
    // Parse hex
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    
    try {
      _seed = Color(int.parse(hexColor, radix: 16));
      _recalculateColors();
    } catch (e) {
      debugPrint("Invalid theme color: $hexColor");
    }
  }

  static void _recalculateColors() {
    final hsl = HSLColor.fromColor(_seed);
    
    _primary = _seed;
    _primaryLight = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    _primaryDark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    
    // Secondary is +45 degrees on the color wheel (analogous)
    _secondary = hsl.withHue((hsl.hue + 45) % 360).toColor();
    _secondaryLight = HSLColor.fromColor(_secondary).withLightness(0.8).toColor();
    
    // Tertiary is +90 degrees
    _tertiary = hsl.withHue((hsl.hue + 90) % 360).toColor();
    
    // Sent bubble is a dark variant of primary
    _sentBubble = hsl.withLightness(0.18).withSaturation(0.4).toColor();
  }

  // ── Gradients ──────────────────────────────────────────────
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [_primary, _secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get warmGlow => LinearGradient(
    colors: [_primary, _primaryLight, _secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [_surface, _surfaceContainer],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get sentBubbleGradient => LinearGradient(
    colors: [_sentBubble.withValues(alpha: 0.8), _sentBubble],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static RadialGradient get warmRadialGlow => RadialGradient(
    colors: [_primary.withValues(alpha: 0.15), _primary.withValues(alpha: 0.0)],
    radius: 0.8,
  );

  /// Gradient for a specific channel type
  static LinearGradient channelGradient(ChannelType type) {
    final colors = colorsFor(type);
    return LinearGradient(
      colors: [colors.gradientStart, colors.gradientEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Subtle background tint gradient for channel screens
  static LinearGradient channelBgGradient(ChannelType type) {
    final colors = colorsFor(type);
    return LinearGradient(
      colors: [_surface, colors.bgTint.withValues(alpha: 0.4), _surfaceContainer],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.0, 0.5, 1.0],
    );
  }

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
  static Color get error => _error;

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
      secondaryContainer: _surfaceContainerHigh,
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

  // ── Animation & Physics ─────────────────────────────────────
  
  /// ColorOS Aquamorphic Spring Curve
  static const Curve aquamorphicCurve = Curves.elasticOut;
  
  static Duration get aquamorphicDuration => const Duration(milliseconds: 600);

  // ── Helpers ────────────────────────────────────────────────

  /// Liquid Glass (Apple style) with specular highlights
  static BoxDecoration liquidGlass({
    double opacity = 0.2,
    double radius = 24,
    Color? baseColor,
  }) {
    final color = baseColor ?? _surfaceContainerHigh;
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.15), // Outer specular highlight
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.05), // Inner specular glow
          blurRadius: 20,
          spreadRadius: -5,
          offset: const Offset(0, 5),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2), // Ambient occlusion shadow
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration glassCard({
    double opacity = 0.3,
    double borderOpacity = 0.15,
    double radius = 24,
  }) {
    return BoxDecoration(
      color: _surfaceContainer.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: borderOpacity)),
    );
  }

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

  /// Creates a liquid glass card decoration with channel-specific accent
  static BoxDecoration channelCard(ChannelType type, {double radius = 24}) {
    final colors = colorsFor(type);
    return BoxDecoration(
      color: _surfaceContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colors.accentLight.withValues(alpha: 0.25), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: colors.accent.withValues(alpha: 0.08),
          blurRadius: 24,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.06), // Inner liquid highlight
          blurRadius: 10,
          spreadRadius: -4,
          offset: const Offset(0, 4),
        )
      ],
    );
  }
}

/// Holds the color set for each channel type.
class ChannelColors {
  final Color accent;
  final Color accentLight;
  final Color gradientStart;
  final Color gradientEnd;
  final Color bgTint;
  final Color iconBg;

  const ChannelColors({
    required this.accent,
    required this.accentLight,
    required this.gradientStart,
    required this.gradientEnd,
    required this.bgTint,
    required this.iconBg,
  });
}
