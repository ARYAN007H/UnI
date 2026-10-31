import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'palette.dart';

/// Holds the app's live theme state: which couple palette is applied and
/// which mode (system/light/dark) the user prefers.
///
/// Replaces the legacy static-mutable `AppTheme` — one owner, notify-driven,
/// safe to listen to from MaterialApp rebuilds. The couple color's source of
/// truth stays in the database (`couples.theme_color_hex`); call
/// [applyCoupleColor] whenever it changes.
class ThemeController extends ChangeNotifier {
  static const _modePrefKey = 'ui.theme_mode';

  CouplePalette _palette = CouplePalette.fallback;
  ThemeMode _mode = ThemeMode.system;

  CouplePalette get palette => _palette;
  ThemeMode get mode => _mode;

  ThemeController() {
    _restoreMode();
  }

  Future<void> _restoreMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_modePrefKey);
      if (saved != null && saved != _mode.name) {
        _mode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.system,
        );
        notifyListeners();
      }
    } catch (_) {
      // Preferences unavailable (first run / web storage limits) — stay system.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modePrefKey, mode.name);
    } catch (_) {
      // Non-fatal — mode still applies for this session.
    }
  }

  /// Applies the couple's color. Invalid/garbage hex falls back to the
  /// default terracotta inside [CouplePalette.fromHex] — never throws.
  void applyCoupleColor(String? hex) {
    final next = CouplePalette.fromHex(hex);
    if (next.seed == _palette.seed) return;
    _palette = next;
    notifyListeners();
  }
}
