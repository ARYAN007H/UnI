import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'config/supabase_config.dart';
import 'core/theme/theme.dart';
import 'core/widgets/widgets.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/shell/home_shell.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/daily_question_service.dart';
import 'services/local_cache_service.dart';
import 'services/media_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handler — ensures uncaught errors don't blank the screen.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FATAL] FlutterError: ${details.exception}');
  };

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('[INIT] .env load failed (may be normal on web): $e');
  }

  // SystemChrome is mobile-only.
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF171412),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  } catch (e) {
    debugPrint('[INIT] Supabase init failed: $e');
    runApp(const _ErrorApp(
        message: 'Failed to connect. Check your internet and try again.'));
    return;
  }

  // Local cache early — mandatory for the local-first UI (plan §7.1).
  LocalCacheService? localCache;
  try {
    localCache = LocalCacheService();
    await localCache.initialize();
  } catch (e) {
    debugPrint('[INIT] LocalCache init failed: $e');
    // An uninitialized instance poisons every downstream call — hand over null
    // so services self-heal or degrade to network-only (plan §7.1).
    localCache = null;
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(UAndI(localCacheService: localCache, prefs: prefs));
}

class UAndI extends StatefulWidget {
  final LocalCacheService? localCacheService;
  final SharedPreferences prefs;

  const UAndI({super.key, this.localCacheService, required this.prefs});

  @override
  State<UAndI> createState() => _UAndIState();
}

class _UAndIState extends State<UAndI> {
  late final AuthService _authService;
  late final ChatService _chatService;
  late final PresenceService _presenceService;
  late final MediaService _mediaService;
  late final NotificationService _notificationService;
  late final DailyQuestionService _dailyQuestionService;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _chatService = ChatService();
    _presenceService = PresenceService();
    _mediaService = MediaService(cache: widget.localCacheService);
    _notificationService = NotificationService();
    _dailyQuestionService = DailyQuestionService(cache: widget.localCacheService);
    _themeController = ThemeController();

    _authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final couple = _authService.couple;
    final user = _authService.currentUser;
    if (couple != null && user != null) {
      _chatService.initialize(
        couple.id,
        cache: widget.localCacheService,
        mediaService: _mediaService,
      );
      _presenceService.subscribe(couple.id, user.id);
      _chatService.subscribeToTyping(couple.id, user.id); // kept no-op (§7.3)
      _notificationService.initialize(user.id);
      _themeController.applyCoupleColor(couple.themeColorHex);
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _authService.dispose();
    _chatService.dispose();
    _presenceService.dispose();
    _mediaService.dispose();
    _notificationService.dispose();
    _dailyQuestionService.dispose();
    _themeController.dispose();
    widget.localCacheService?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = ServiceBundle(
      authService: _authService,
      chatService: _chatService,
      presenceService: _presenceService,
      mediaService: _mediaService,
      dailyQuestionService: _dailyQuestionService,
      themeController: _themeController,
      localCache: widget.localCacheService,
      prefs: widget.prefs,
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_authService, _themeController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'U&i',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(_themeController.palette),
          darkTheme: AppTheme.dark(_themeController.palette),
          themeMode: _themeController.mode,
          home: Builder(
            builder: (context) {
              if (_authService.loading) return const _SplashScreen();
              if (!_authService.isLoggedIn) {
                return AuthScreen(authService: _authService);
              }
              if (_authService.couple == null) {
                return OnboardingFlow(
                  authService: _authService,
                  dailyQuestionService: _dailyQuestionService,
                  mediaService: _mediaService,
                  prefs: widget.prefs,
                );
              }
              return HomeShell(services: bundle);
            },
          ),
        );
      },
    );
  }
}

/// Paper splash with the app's single allowed gradient (docs/design/
/// icon-splash.md, plan §4.3 rule 1). Wordmark in Fraunces; the spinner
/// lives here only.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.tokensOf(context);
    final palette = CouplePalette.fallback;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.base, Color.lerp(t.base, palette.seed, 0.02)!],
          ),
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppDurations.slow,
            curve: AppMotion.emphasized,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - value)),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('U&i', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your private space together',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: t.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.accent.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when Supabase or critical init fails.
class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(CouplePalette.fallback),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 56, color: AppTheme.tokensOf(context).error),
                const SizedBox(height: AppSpacing.lg),
                Text('Connection Error',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Try again',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showAppToast(
                      context, 'Restart the app to try connecting again.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
