
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';
import '../../services/presence_service.dart';
import '../../services/backup_service.dart';
import '../../widgets/channel_card.dart';
import '../../widgets/couple_header.dart';
import '../../widgets/quick_actions.dart';
import '../../widgets/responsive_wrapper.dart';
import '../chat/general_chat_screen.dart';
import '../chat/photos_screen.dart';
import '../chat/plans_screen.dart';
import '../chat/random_screen.dart';
import '../chat/chat_screen.dart';
import '../globe/memory_globe_screen.dart';
import '../../widgets/liquid_glass_pill.dart';
import '../settings/settings_screen.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;
  final MediaService mediaService;
  final BackupService backupService;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.chatService,
    required this.presenceService,
    required this.mediaService,
    required this.backupService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedPillIndex = 0;

  @override
  Widget build(BuildContext context) {
    final couple = widget.authService.couple;
    final days = couple != null
        ? DateTime.now().difference(couple.pairedAt).inDays
        : 0;

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ambient ColorOS style backdrop
          Positioned.fill(
            child: Container(
              color: AppTheme.surface,
              child: Stack(
                children: [
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withValues(alpha: 0.15),
                      ),
                    ).animate(onPlay: (c) => c.repeat())
                     .move(duration: 10.seconds, begin: const Offset(0, 0), end: const Offset(-50, 50))
                     .move(duration: 12.seconds, delay: 10.seconds, begin: const Offset(-50, 50), end: const Offset(0, 0)),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: ResponsiveWrapper(
              maxWidth: 520,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()), // ColorOS physics
                slivers: [
                  // Header with logo
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  // Email verification banner
                  if (!widget.authService.isEmailVerified)
                    SliverToBoxAdapter(child: _buildVerificationBanner(context)),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  // Couple header with avatars
                  SliverToBoxAdapter(
                    child: CoupleHeader(
                      myProfile: widget.authService.profile,
                      partnerProfile: widget.authService.partnerProfile,
                      presenceService: widget.presenceService,
                      daysTogether: days,
                      isVanillaMode: couple?.isVanillaMode ?? false,
                    ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  // Quick actions
                  SliverToBoxAdapter(
                    child: QuickActions(
                      authService: widget.authService,
                      chatService: widget.chatService,
                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  // Memory Globe Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildMemoryGlobeBanner(context),
                    ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  // Channels section header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'YOUR SPACES',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_rounded, color: AppTheme.onSurfaceVariant),
                            onPressed: () => _showCreateChannel(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  // Channel list
                  _buildChannelList(context),
                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ],
              ),
            ),
          ),
          
          // Liquid Glass Pill
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: LiquidGlassPill(
                selectedIndex: _selectedPillIndex,
                onItemSelected: (index) {
                  setState(() => _selectedPillIndex = index);
                  if (index == 2) { // Globe
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemoryGlobeScreen(
                          chatService: widget.chatService,
                          authService: widget.authService,
                        ),
                      ),
                    );
                  } else if (index == 3) { // Settings
                    _showSettings(context);
                  }
                },
                items: const [
                  LiquidPillItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
                  LiquidPillItem(icon: Icons.dashboard_rounded, label: 'Spaces'),
                  LiquidPillItem(icon: Icons.public_rounded, label: 'Globe'),
                  LiquidPillItem(icon: Icons.settings_rounded, label: 'Settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          // Warm gradient heart icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ShaderMask(
              shaderCallback: (b) =>
                  AppTheme.primaryGradient.createShader(b),
              child: Text(
                'U&i',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded,
                color: AppTheme.onSurfaceVariant, size: 22),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildVerificationBanner(BuildContext context) {
    final remaining = widget.authService.profile?.gracePeriodRemaining ?? Duration.zero;
    final hours = remaining.inHours;
    final timeLabel = hours > 0 ? '${hours}h left' : 'Expiring soon';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.secondary.withValues(alpha: 0.12),
              AppTheme.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.secondary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: AppTheme.secondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: TextButton(
                onPressed: () async {
                  try {
                    await widget.authService.sendVerificationEmail();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification link sent! Check your email.'),
                        ),
                      );
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to send link. Try again.')),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: AppTheme.secondary.withValues(alpha: 0.12),
                ),
                child: Text(
                  'Verify',
                  style: TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildMemoryGlobeBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemoryGlobeScreen(
              chatService: widget.chatService,
              authService: widget.authService,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1E2430),
              AppTheme.primary.withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Text('🌍', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3D Memory Globe',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explore your geotagged memories',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelList(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.chatService,
      builder: (context, _) {
        final channels = widget.chatService.channels;
        if (channels.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded,
                          size: 28,
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Setting up your spaces...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your channels will appear here',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final channel = channels[index];
              return ChannelCard(
                channel: channel,
                previewText: _previewFor(channel),
                onTap: () => _openChannel(context, channel),
              )
                  .animate(delay: Duration(milliseconds: 60 * index + 300))
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.05, end: 0);
            },
            childCount: channels.length,
          ),
        );
      },
    );
  }

  String? _previewFor(Channel channel) {
    switch (channel.type) {
      case ChannelType.general:
        return channel.lastMessageContent ?? channel.description;
      case ChannelType.photos:
        return 'Share your moments together 📸';
      case ChannelType.plans:
        final plans = widget.chatService.plansForChannel(channel.id);
        final upcoming = plans.where((p) => !p.isCompleted).length;
        if (upcoming > 0) return '$upcoming plan${upcoming == 1 ? '' : 's'} waiting ✨';
        return 'Plan your next adventure 🗺️';
      case ChannelType.random:
        return widget.chatService.currentPrompt.text.length > 40
            ? '${widget.chatService.currentPrompt.text.substring(0, 40)}...'
            : widget.chatService.currentPrompt.text;
      case ChannelType.custom:
        return channel.description;
    }
  }

  void _openChannel(BuildContext context, Channel channel) {
    Widget screen;
    switch (channel.type) {
      case ChannelType.general:
        screen = GeneralChatScreen(
          channel: channel,
          authService: widget.authService,
          chatService: widget.chatService,
          presenceService: widget.presenceService,
          mediaService: widget.mediaService,
        );
        break;
      case ChannelType.photos:
        screen = PhotosScreen(
          channel: channel,
          authService: widget.authService,
          chatService: widget.chatService,
          presenceService: widget.presenceService,
          mediaService: widget.mediaService,
        );
        break;
      case ChannelType.plans:
        screen = PlansScreen(
          channel: channel,
          authService: widget.authService,
          chatService: widget.chatService,
          presenceService: widget.presenceService,
        );
        break;
      case ChannelType.random:
        screen = RandomScreen(
          channel: channel,
          authService: widget.authService,
          chatService: widget.chatService,
          presenceService: widget.presenceService,
        );
        break;
      case ChannelType.custom:
        screen = ChatScreen(
          channel: channel,
          authService: widget.authService,
          chatService: widget.chatService,
          presenceService: widget.presenceService,
        );
        break;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }



  void _showCreateChannel(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emojiOptions = ['💬', '📸', '📅', '✨', '❤️', '🎵', '🎮', '📝', '🌟', '🎁'];
    String selectedEmoji = '💬';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                  color: AppTheme.outline.withValues(alpha: 0.2)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('New Channel',
                  style: Theme.of(ctx)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Pick an emoji and name for your channel',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: AppTheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              // Emoji picker row
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: emojiOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final emoji = emojiOptions[i];
                    final selected = emoji == selectedEmoji;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : AppTheme.outlineVariant,
                          ),
                        ),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Channel name',
                  prefixIcon: Icon(Icons.tag_rounded,
                      size: 20, color: AppTheme.onSurfaceVariant),
                  filled: true,
                  fillColor: AppTheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppTheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        width: 1.5),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 20),
              Container(
                height: 52,
                decoration: AppTheme.gradientButton(),
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isNotEmpty) {
                      widget.chatService.createChannel(
                        name: nameCtrl.text.trim(),
                        icon: selectedEmoji,
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Create Channel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          authService: widget.authService,
          chatService: widget.chatService,
          backupService: widget.backupService,
        ),
      ),
    );
  }
}

