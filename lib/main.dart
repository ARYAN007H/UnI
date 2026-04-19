import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/presence_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pair_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for immersive dark mode
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const CoupleChat());
}

class CoupleChat extends StatefulWidget {
  const CoupleChat({super.key});

  @override
  State<CoupleChat> createState() => _CoupleChatState();
}

class _CoupleChatState extends State<CoupleChat> {
  late final AuthService _authService;
  late final ChatService _chatService;
  late final PresenceService _presenceService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _chatService = ChatService();
    _presenceService = PresenceService();

    // When auth state changes, initialize chat & presence if paired
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
      title: 'Couple Chat',
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
              // Animated heart icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Couple Chat',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
