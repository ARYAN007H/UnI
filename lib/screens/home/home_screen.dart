import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              _buildPartnerStatus(context),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Channels', style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildChannelList(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.favorite_rounded, size: 28, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              authService.couple?.coupleName ?? 'Couple Chat',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            color: AppTheme.onSurfaceVariant,
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0);
  }

  Widget _buildPartnerStatus(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListenableBuilder(
        listenable: presenceService,
        builder: (context, _) {
          final partner = authService.partnerProfile;
          if (partner == null) return const SizedBox.shrink();

          final online = presenceService.partnerOnline;
          final lastSeen = presenceService.partnerLastSeen ?? partner.lastSeen;

          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    _avatar(partner, online),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(partner.displayName, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: online ? const Color(0xFF4ADE80) : AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              online ? 'Online now' : (lastSeen != null ? 'Last seen ${timeago.format(lastSeen)}' : 'Offline'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant),
                            ),
                          ]),
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
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _avatar(Profile p, bool online) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
          child: p.avatarUrl == null
              ? Text(p.displayName[0].toUpperCase(), style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700))
              : null,
        ),
        if (online)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.surface, width: 2),
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
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('No channels yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.onSurfaceVariant)),
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
            ).animate(delay: Duration(milliseconds: 100 * index)).fadeIn().slideX(begin: 0.05, end: 0);
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
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: FloatingActionButton(
        onPressed: () => _showCreateChannel(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showCreateChannel(BuildContext context) {
    final nameCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Channel', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 20),
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Channel name', prefixIcon: Icon(Icons.tag_rounded))),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  chatService.createChannel(name: nameCtrl.text.trim());
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(authService.profile?.displayName ?? 'User'),
              subtitle: Text('@${authService.profile?.username ?? ''}'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () { Navigator.pop(ctx); authService.signOut(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const _ChannelTile({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(channel.icon, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${channel.name}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      if (channel.description.isNotEmpty)
                        Text(channel.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
