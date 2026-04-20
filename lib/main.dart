import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/presence_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pair_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");

  // Immersive warm dark system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF131118),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const UAndI());
}

class UAndI extends StatefulWidget {
  const UAndI({super.key});

  @override
  State<UAndI> createState() => _UAndIState();
}

class _UAndIState extends State<UAndI> {
  late final AuthService _authService;
  late final ChatService _chatService;
  late final PresenceService _presenceService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _chatService = ChatService();
    _presenceService = PresenceService();
    _authService.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (_authService.couple != null && _authService.currentUser != null) {
      _chatService.initialize(_authService.couple!.id);
      _presenceService.subscribe(
        _authService.couple!.id,
        _authService.currentUser!.id,
      );
      _chatService.subscribeToTyping(
        _authService.couple!.id,
        _authService.currentUser!.id,
      );
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    _authService.dispose();
    _chatService.dispose();
    _presenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'U&i',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ListenableBuilder(
        listenable: _authService,
        builder: (context, _) {
          if (_authService.loading) {
            return const _SplashScreen();
          }
          if (!_authService.isLoggedIn) {
            return LoginScreen(authService: _authService);
          }
          // Enforce email verification after 24-hour grace period
          if (!_authService.isEmailVerified &&
              _authService.isGracePeriodExpired) {
            return VerifyEmailScreen(authService: _authService);
          }
          if (_authService.couple == null) {
            return PairScreen(authService: _authService);
          }
          return HomeScreen(
            authService: _authService,
            chatService: _chatService,
            presenceService: _presenceService,
          );
        },
      ),
    );
  }
}

// ── Splash Screen ────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warm pulsing heart
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  'U&i',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your private space together',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
