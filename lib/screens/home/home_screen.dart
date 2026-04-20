import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../widgets/responsive_wrapper.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatelessWidget {
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.chatService,
    required this.presenceService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: ResponsiveWrapper(
            maxWidth: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                // Email verification reminder banner
                if (!authService.isEmailVerified)
                  _buildVerificationBanner(context),
                const SizedBox(height: 12),
                _buildPartnerCard(context),
                const SizedBox(height: 6),
                _buildDaysTogether(context),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'CHANNELS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildChannelList(context)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildVerificationBanner(BuildContext context) {
    final remaining = authService.profile?.gracePeriodRemaining ?? Duration.zero;
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
                    await authService.sendVerificationEmail();
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          // Warm gradient heart icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                size: 20, color: Colors.white),
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

  Widget _buildPartnerCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListenableBuilder(
        listenable: presenceService,
        builder: (context, _) {
          final partner = authService.partnerProfile;
          if (partner == null) return const SizedBox.shrink();

          final online = presenceService.partnerOnline;
          final lastSeen =
              presenceService.partnerLastSeen ?? partner.lastSeen;

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: online
                        ? AppTheme.success.withValues(alpha: 0.2)
                        : AppTheme.outline.withValues(alpha: 0.15),
                  ),
                  boxShadow: online
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.success.withValues(alpha: 0.06),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    _avatar(partner, online),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner.displayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: online
                                      ? AppTheme.success
                                      : AppTheme.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                  boxShadow: online
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.success
                                                .withValues(alpha: 0.4),
                                            blurRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                online
                                    ? 'Online now'
                                    : (lastSeen != null
                                        ? 'Last seen ${timeago.format(lastSeen)}'
                                        : 'Offline'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: online
                                          ? AppTheme.success
                                          : AppTheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          if (partner.statusText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              partner.statusText,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 400.ms);
  }

  Widget _buildDaysTogether(BuildContext context) {
    final couple = authService.couple;
    if (couple == null) return const SizedBox.shrink();

    final days = DateTime.now().difference(couple.pairedAt).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.08),
              AppTheme.secondary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_rounded,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(
              'Together $days day${days == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _avatar(Profile p, bool online) {
    return Stack(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: online ? AppTheme.primaryGradient : null,
            color: online ? null : AppTheme.surfaceContainerHigh,
            border: online
                ? null
                : Border.all(color: AppTheme.outline.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.surfaceContainerHigh,
            backgroundImage:
                p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
            child: p.avatarUrl == null
                ? Text(
                    p.displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChannelList(BuildContext context) {
    return ListenableBuilder(
      listenable: chatService,
      builder: (context, _) {
        final channels = chatService.channels;
        if (channels.isEmpty) {
          return Center(
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
                  'No channels yet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap + to create your first channel',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            return _ChannelTile(
              channel: channels[index],
              onTap: () => _openChannel(context, channels[index]),
            )
                .animate(delay: Duration(milliseconds: 80 * index))
                .fadeIn(duration: 350.ms)
                .slideX(begin: 0.03, end: 0);
          },
        );
      },
    );
  }

  void _openChannel(BuildContext context, Channel channel) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ChatScreen(
          channel: channel,
          authService: authService,
          chatService: chatService,
          presenceService: presenceService,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
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

  Widget _buildFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => _showCreateChannel(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
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
                      chatService.createChannel(
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
    final couple = authService.couple;
    final days = couple != null
        ? DateTime.now().difference(couple.pairedAt).inDays
        : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
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
              // Profile card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(
                    opacity: 0.4, borderOpacity: 0.1, radius: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        (authService.profile?.displayName ?? 'U')[0]
                            .toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authService.profile?.displayName ?? 'User',
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '@${authService.profile?.username ?? ''}',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Couple stats
              if (couple != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCard(
                      opacity: 0.4, borderOpacity: 0.1, radius: 16),
                  child: Row(
                    children: [
                      _statItem(ctx, '❤️', '$days', 'Days Together'),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppTheme.outline.withValues(alpha: 0.2),
                      ),
                      _statItem(
                        ctx,
                        '📅',
                        couple.anniversaryDate != null
                            ? '${couple.anniversaryDate!.month}/${couple.anniversaryDate!.day}'
                            : '—',
                        'Anniversary',
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: AppTheme.outline.withValues(alpha: 0.2),
                      ),
                      _statItem(
                        ctx,
                        '💬',
                        '${chatService.channels.length}',
                        'Channels',
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              
              // Theme Color Picker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: ListenableBuilder(
                        listenable: authService,
                        builder: (context, _) {
                          final currentHex = authService.couple?.themeColorHex ?? '#FFFF6B6B';
                          
                          final presetColors = [
                            {'name': 'Passionate Coral', 'hex': '#FFFF6B6B'},
                            {'name': 'Ocean Blue', 'hex': '#FF4A90E2'},
                            {'name': 'Lavender Haze', 'hex': '#FF9B51E0'},
                            {'name': 'Emerald Forest', 'hex': '#FF27AE60'},
                            {'name': 'Golden Hour', 'hex': '#FFF2C94C'},
                          ];

                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: presetColors.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, index) {
                              final hex = presetColors[index]['hex']!;
                              final color = Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16));
                              final isSelected = currentHex.toUpperCase() == hex.toUpperCase();
                              
                              return GestureDetector(
                                onTap: () => authService.updateThemeColor(hex),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected 
                                        ? Border.all(color: Colors.white, width: 3)
                                        : null,
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                                        : null,
                                  ),
                                  child: isSelected 
                                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                                      : null,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1),
              
              // Emergency / Vanilla Mode Toggle
              ListenableBuilder(
                listenable: authService,
                builder: (context, _) {
                  final isVanilla = authService.couple?.isVanillaMode ?? false;
                  return SwitchListTile(
                    title: Text(
                      'Emergency / Vanilla Mode',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Disables intimate themes and animations.',
                      style: TextStyle(
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.security_rounded, color: AppTheme.error, size: 20),
                    ),
                    value: isVanilla,
                    activeColor: AppTheme.error,
                    onChanged: (val) {
                      authService.toggleVanillaMode(val);
                    },
                  );
                },
              ),
              
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout_rounded,
                    color: AppTheme.primary, size: 22),
                title: Text(
                  'Sign Out',
                  style: TextStyle(color: AppTheme.primary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  authService.signOut();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(
      BuildContext ctx, String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            label,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Channel Tile ──────────────────────────────────────────────
class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const _ChannelTile({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.primary.withValues(alpha: 0.06),
          highlightColor: AppTheme.primary.withValues(alpha: 0.03),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Channel icon container
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Center(
                    child: Text(channel.icon,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${channel.name}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (channel.description.isNotEmpty)
                        Text(
                          channel.description,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
