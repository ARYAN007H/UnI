import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/chat_service.dart';

/// Full settings screen extracted from HomeScreen bottom sheet.
/// Includes profile, couple stats, theme picker, backup, and account management.
class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final ChatService chatService;
  final BackupService backupService;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.chatService,
    required this.backupService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isEditingName = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.authService.profile?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // App bar
              SliverToBoxAdapter(child: _buildAppBar(context)),
              // Profile card
              SliverToBoxAdapter(child: _buildProfileCard(context)),
              // Couple stats
              SliverToBoxAdapter(child: _buildCoupleStats(context)),
              // Theme picker
              SliverToBoxAdapter(child: _buildThemePicker(context)),
              // Options list
              SliverToBoxAdapter(child: _buildOptions(context)),
              // Danger zone
              SliverToBoxAdapter(child: _buildDangerZone(context)),
              // App info
              SliverToBoxAdapter(child: _buildAppInfo(context)),
              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: AppTheme.onSurface,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) {
        final profile = widget.authService.profile;
        final partner = widget.authService.partnerProfile;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.liquidGlass(opacity: 0.25, radius: 20),
            child: Column(
              children: [
                // Your profile
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: Center(
                        child: Text(
                          (profile?.displayName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditingName)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nameController,
                                    autofocus: true,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                      ),
                                    ),
                                    onSubmitted: (_) => _saveName(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.check_rounded, color: AppTheme.success, size: 20),
                                  onPressed: _saveName,
                                ),
                              ],
                            )
                          else
                            GestureDetector(
                              onTap: () => setState(() => _isEditingName = true),
                              child: Row(
                                children: [
                                  Text(
                                    profile?.displayName ?? 'User',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(Icons.edit_rounded, size: 14, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            '@${profile?.username ?? ''}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Partner info
                if (partner != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.secondary.withValues(alpha: 0.4),
                                AppTheme.primary.withValues(alpha: 0.3),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              partner.displayName[0].toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partner.displayName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'Your person 💕',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0, duration: 300.ms),
        );
      },
    );
  }

  Widget _buildCoupleStats(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.authService,
      builder: (context, _) {
        final couple = widget.authService.couple;
        if (couple == null) return const SizedBox.shrink();

        final days = DateTime.now().difference(couple.pairedAt).inDays;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: AppTheme.glassCard(opacity: 0.3, borderOpacity: 0.1, radius: 20),
            child: Row(
              children: [
                _statItem(context, '❤️', '$days', 'Days Together'),
                Container(width: 1, height: 36, color: AppTheme.outline.withValues(alpha: 0.2)),
                _statItem(
                  context,
                  '📅',
                  couple.anniversaryDate != null
                      ? '${couple.anniversaryDate!.month}/${couple.anniversaryDate!.day}'
                      : '—',
                  'Anniversary',
                ),
                Container(width: 1, height: 36, color: AppTheme.outline.withValues(alpha: 0.2)),
                _statItem(
                  context,
                  '💬',
                  '${widget.chatService.channels.length}',
                  'Channels',
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
        );
      },
    );
  }

  Widget _statItem(BuildContext ctx, String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.glassCard(opacity: 0.3, borderOpacity: 0.1, radius: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_rounded, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'App Theme',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ListenableBuilder(
                listenable: widget.authService,
                builder: (context, _) {
                  final currentHex = widget.authService.couple?.themeColorHex ?? '#FFFF6B6B';

                  const presetColors = [
                    {'name': 'Passionate Coral', 'hex': '#FFFF6B6B'},
                    {'name': 'Ocean Blue', 'hex': '#FF4A90E2'},
                    {'name': 'Lavender Haze', 'hex': '#FF9B51E0'},
                    {'name': 'Emerald Forest', 'hex': '#FF27AE60'},
                    {'name': 'Golden Hour', 'hex': '#FFF2C94C'},
                    {'name': 'Rose Pink', 'hex': '#FFE91E63'},
                    {'name': 'Teal Dream', 'hex': '#FF009688'},
                  ];

                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: presetColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final hex = presetColors[index]['hex']!;
                      final name = presetColors[index]['name']!;
                      final color = Color(int.parse(hex.replaceAll('#', 'FF'), radix: 16));
                      final isSelected = currentHex.toUpperCase() == hex.toUpperCase();

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.authService.updateThemeColor(hex);
                        },
                        child: Tooltip(
                          message: name,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: AppTheme.glassCard(opacity: 0.3, borderOpacity: 0.1, radius: 20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Vanilla / Emergency Mode
            ListenableBuilder(
              listenable: widget.authService,
              builder: (context, _) {
                final isVanilla = widget.authService.couple?.isVanillaMode ?? false;
                return SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    'Emergency Mode',
                    style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Text(
                    'Disables intimate themes and animations',
                    style: TextStyle(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12),
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
                  activeTrackColor: AppTheme.error,
                  onChanged: (val) => widget.authService.toggleVanillaMode(val),
                );
              },
            ),
            Divider(height: 1, color: AppTheme.outline.withValues(alpha: 0.1)),
            // Backup
            if (!kIsWeb) ...[
              _buildBackupSection(context),
              Divider(height: 1, color: AppTheme.outline.withValues(alpha: 0.1)),
            ],
          ],
        ),
      ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
    );
  }

  Widget _buildBackupSection(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.backupService,
      builder: (context, _) {
        final hasAccount = widget.backupService.isSignedIn;
        final isBackingUp = widget.backupService.isBackingUp;
        final isRestoring = widget.backupService.isRestoring;
        final lastBackup = widget.backupService.lastBackup;

        return Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(Icons.cloud_sync_rounded, color: AppTheme.primary, size: 22),
              title: Text(
                'Google Drive Backup',
                style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onSurface, fontSize: 15),
              ),
              subtitle: Text(
                hasAccount
                    ? lastBackup != null
                        ? 'Last backup: ${_formatBackupTime(lastBackup)}'
                        : 'Connected • No backups yet'
                    : 'Not connected',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
              trailing: isBackingUp || isRestoring
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    )
                  : null,
              onTap: () async {
                if (!hasAccount) {
                  await widget.backupService.signIn();
                }
              },
            ),
            if (hasAccount)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        icon: Icons.upload_rounded,
                        label: 'Backup Now',
                        color: AppTheme.primary,
                        onTap: isBackingUp || isRestoring ? null : () => widget.backupService.backup(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionButton(
                        icon: Icons.download_rounded,
                        label: 'Restore',
                        color: AppTheme.onSurfaceVariant,
                        onTap: isBackingUp || isRestoring ? null : () => widget.backupService.restore(),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDangerZone(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: AppTheme.glassCard(opacity: 0.3, borderOpacity: 0.1, radius: 20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Icon(Icons.logout_rounded, color: AppTheme.primary, size: 22),
              title: Text(
                'Sign Out',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              onTap: () {
                _confirmAction(
                  context,
                  title: 'Sign Out',
                  message: 'Are you sure you want to sign out?',
                  action: 'Sign Out',
                  onConfirm: () {
                    Navigator.pop(context); // dismiss dialog
                    Navigator.pop(context); // pop settings
                    widget.authService.signOut();
                  },
                );
              },
            ),
          ],
        ),
      ).animate().fadeIn(delay: 400.ms, duration: 300.ms),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Text(
            'U&i • v0.1.0',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your private space together 💕',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 4),
            Text(
              'Web version',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.onSurfaceVariant.withValues(alpha: 0.25),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message, style: TextStyle(color: AppTheme.onSurfaceVariant)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: onConfirm,
            child: Text(action, style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.authService.profile?.displayName) {
      try {
        await widget.authService.updateDisplayName(newName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update name: $e')),
          );
        }
      }
    }
    setState(() => _isEditingName = false);
  }

  String _formatBackupTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
