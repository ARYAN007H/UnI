import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Route names + transition helpers for the 4-tab app (plan §5).
///
/// [RouteNames] is the single registry of paths. Feature screens register
/// their routes in [AppRouter.onGenerateRoute] as they are built (Agent 3);
/// unnamed routes fall through to `MaterialApp.builder`/`home` wiring.
abstract final class RouteNames {
  static const String auth = '/auth';
  static const String pair = '/pair';
  static const String home = '/home';
  static const String settings = '/settings';

  // Home tab detail routes
  static const String chat = '/chat';
  static const String us = '/us';
  static const String plans = '/plans';
}

/// Fade-through transitions on the token motion (no platform default zooms —
/// the app moves on one curve, plan §4).
abstract final class AppRouter {
  static Route<T> fadeThrough<T>(Widget page, {RouteSettings? settings}) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: AppDurations.base,
        reverseTransitionDuration: AppDurations.fast,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(curve: AppMotion.emphasized, parent: animation),
          child: child,
        ),
      );

  static Route<T> slideUp<T>(Widget page, {RouteSettings? settings}) =>
      PageRouteBuilder<T>(
        settings: settings,
        transitionDuration: AppDurations.slow,
        reverseTransitionDuration: AppDurations.base,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            curve: AppMotion.emphasized,
            parent: animation,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );

  /// Fill in as feature screens land. Returning null defers to the
  /// MaterialApp `home`/`builder` wiring in main.dart (Agent 3's lane).
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) => null;
}
