import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/daily_question_service.dart';
import '../../services/local_cache_service.dart';
import '../../services/media_service.dart';
import '../../services/presence_service.dart';
import '../chat/chat_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/secure_media_screen.dart';
import '../plans/plans_screen.dart';
import '../us/us_screen.dart';

/// The 4-tab app shell (plan §5): Home / Chat / Us / Plans.
/// Owns the tab state; tabs are kept alive in an [IndexedStack] so chat
/// scroll position and Home state survive tab switches. Also nudges the
/// one-time media-encryption setup after pairing (agent2 §7.5).
class HomeShell extends StatefulWidget {
  final ServiceBundle services;

  const HomeShell({super.key, required this.services});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.home;

  void _open(AppTab tab) => setState(() => _tab = tab);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSecureMedia());
  }

  Future<void> _maybeSecureMedia() async {
    final auth = widget.services.authService;
    final user = auth.currentUser;
    if (user == null || auth.couple == null) return;
    final done = widget.services.prefs
            .getBool('${SecureMediaScreen.flagPrefix}${user.id}') ??
        false;
    if (done || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SecureMediaScreen(
        authService: auth,
        prefs: widget.services.prefs,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          HomeScreen(services: s, onOpenTab: _open),
          ChatScreen(services: s),
          UsScreen(services: s),
          PlansScreen(services: s),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        current: _tab,
        onTap: _open,
      ),
    );
  }
}

/// Typed bundle passed down through tabs — one place wires the services
/// (main.dart owns construction; screens stay constructor-injected).
class ServiceBundle {
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;
  final MediaService mediaService;
  final DailyQuestionService dailyQuestionService;
  final ThemeController themeController;
  final LocalCacheService? localCache;
  final SharedPreferences prefs;

  const ServiceBundle({
    required this.authService,
    required this.chatService,
    required this.presenceService,
    required this.mediaService,
    required this.dailyQuestionService,
    required this.themeController,
    required this.localCache,
    required this.prefs,
  });
}
