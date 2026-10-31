import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../services/account_deletion_service.dart';
import '../../services/crypto_service.dart';
import '../../services/export_service.dart';
import '../onboarding/secure_media_screen.dart';
import '../shell/home_shell.dart';

/// Settings — "What do I control?" (docs/design/settings.md). The Trust
/// section is first-class: export, "what leaves your device", encryption
/// recovery, delete.
class SettingsScreen extends StatelessWidget {
  final ServiceBundle services;

  const SettingsScreen({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final auth = services.authService;
    final tc = services.themeController;

    return Scaffold(
      appBar: const AppAppBar(title: 'Settings'),
      body: ListenableBuilder(
        listenable: Listenable.merge([auth, tc]),
        builder: (context, _) {
          final profile = auth.profile;
          final couple = auth.couple;
          return ListView(
            children: [
              SectionHeader(title: 'Profile'),
              ListTile(
                leading: Avatar(name: profile?.displayName ?? '?', imageUrl: profile?.avatarUrl, radius: 22),
                title: Text(profile?.displayName ?? 'You',
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(profile?.username ?? '', style: Theme.of(context).textTheme.bodySmall),
              ),
              _nameEditTile(context),

              SectionHeader(title: 'Us'),
              ListTile(
                title: const Text('Couple'),
                subtitle: Text(couple?.coupleName ?? 'Unnamed couple',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              _accentTile(context),

              SectionHeader(title: 'Trust'),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Export everything'),
                subtitle: const Text('Your data, in your hands — one tap.',
                    style: TextStyle(fontSize: 12)),
                onTap: () => _exportAll(context),
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text('Restore media access'),
                subtitle: const Text('New phone? Your recovery code re-arms it.',
                    style: TextStyle(fontSize: 12)),
                onTap: () => _restoreMedia(context),
              ),
              ListTile(
                leading: const Icon(Icons.enhanced_encryption_outlined),
                title: const Text('Media encryption setup'),
                subtitle: const Text('Show the recovery-code flow again.',
                    style: TextStyle(fontSize: 12)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SecureMediaScreen(
                    authService: services.authService,
                    prefs: services.prefs,
                  ),
                )),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('What leaves your device'),
                onTap: () => _whatLeavesDevice(context),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Delete account',
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => _deleteAccount(context),
              ),

              SectionHeader(title: 'Notifications'),
              SwitchListTile(
                title: const Text('Daily question'),
                value: true,
                onChanged: (_) => showAppToast(
                    context, 'Notification schedules arrive with push (Phase 3).'),
              ),
              SwitchListTile(
                title: const Text('Messages'),
                value: true,
                onChanged: (_) => showAppToast(
                    context, 'Notification schedules arrive with push (Phase 3).'),
              ),

              SectionHeader(title: 'Appearance'),
              ListenableBuilder(
                listenable: tc,
                builder: (context, _) => RadioGroup<ThemeMode>(
                  groupValue: tc.mode,
                  onChanged: (m) => m != null ? tc.setMode(m) : null,
                  child: Column(
                    children: [
                      for (final mode in ThemeMode.values)
                        RadioListTile<ThemeMode>(
                          title: Text(switch (mode) {
                            ThemeMode.system => 'Follow system',
                            ThemeMode.light => 'Paper (light)',
                            ThemeMode.dark => 'Candlelight (dark)',
                          }),
                          value: mode,
                        ),
                    ],
                  ),
                ),
              ),

              SectionHeader(title: 'About'),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('Anniversary'),
                subtitle: Text(
                  couple?.anniversaryDate?.toIso8601String().split(' ').first ??
                      couple?.pairedAt.toIso8601String().split(' ').first ??
                      '—',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              ListTile(
                title: const Text('Version'),
                subtitle: const Text('U&i 0.2.0 · Made by one person, for two.',
                    style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  Widget _nameEditTile(BuildContext context) {
    final auth = services.authService;
    return ListTile(
      leading: const Icon(Icons.edit_outlined),
      title: const Text('Change your name'),
      onTap: () async {
        final controller = TextEditingController(text: auth.profile?.displayName ?? '');
        final result = await showAppSheet<String>(
          context: context,
          title: 'Your name',
          children: [
            AppTextField(controller: controller, autofocus: true),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        );
        if (result != null && result.isNotEmpty) {
          try {
            await auth.updateDisplayName(result);
          } catch (_) {
            if (context.mounted) showAppToast(context, "Couldn't save — try again.");
          }
        }
      },
    );
  }

  Widget _accentTile(BuildContext context) {
    const swatches = [
      '#C4573B', // terracotta (default)
      '#B4552D', // clay
      '#9C4A6E', // plum rose
      '#7A5C3E', // warm oak
      '#4E6E5D', // sage
      '#3E5C76', // dusk blue
      '#8A5A44', // chestnut
      '#B03A2E', // brick
    ];
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Your color'),
      subtitle: const Text('One color, everywhere — for both of you.',
          style: TextStyle(fontSize: 12)),
      onTap: () async {
        final picked = await showAppSheet<String>(
          context: context,
          title: 'Your color',
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final hex in swatches)
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    onTap: () => Navigator.of(context).pop(hex),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CouplePalette.fromHex(hex).accent,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
        if (picked != null) {
          await services.authService.updateThemeColor(picked);
          services.themeController.applyCoupleColor(picked);
        }
      },
    );
  }

  Future<void> _exportAll(BuildContext context) async {
    final couple = services.authService.couple;
    final cache = services.localCache;
    if (couple == null || cache == null) {
      showAppToast(context, "Export needs a paired account and your local data.");
      return;
    }
    showAppToast(context, 'Packing your memories…');
    try {
      final exporter = ExportService(cache: cache);
      final result = await exporter.exportAll(
        coupleId: couple.id,
        onMediaProgress: (done, total) {},
      );
      if (!context.mounted) return;
      // manifestJson is a string — persist it next to the media folder so
      // the share sheet has a real file to hand off.
      XFile? manifestFile;
      if (result.directory != null) {
        final file = File('${result.directory}/manifest.json');
        await file.writeAsString(result.manifestJson);
        manifestFile = XFile(file.path);
      }
      await SharePlus.instance.share(ShareParams(
        files: manifestFile != null ? [manifestFile] : null,
        text: 'U&i export — ${result.messageCount} messages, '
            '${result.mediaCount} media files.',
      ));
      if (context.mounted && result.directory != null) {
        showAppToast(context, 'Saved to ${result.directory}');
      }
    } catch (e) {
      if (context.mounted) showAppToast(context, "Couldn't export — try again.");
    }
  }

  Future<void> _restoreMedia(BuildContext context) async {
    final couple = services.authService.couple;
    final me = services.authService.currentUser;
    if (couple == null || me == null) return;
    final controller = TextEditingController();
    final code = await showAppSheet<String>(
      context: context,
      title: 'Restore media access',
      children: [
        AppTextField(
          label: 'Your recovery code',
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Restore',
          expand: true,
          onPressed: controller.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(controller.text.trim()),
        ),
      ],
    );
    if (code == null || code.trim().isEmpty) return;
    final ok = await CryptoService().recoverFromRecoveryCode(
      coupleId: couple.id,
      myUserId: me.id,
      recoveryCode: code.trim(),
    );
    if (context.mounted) {
      showAppToast(
          context, ok ? 'Media access restored on this device.' : "That code didn't match.");
    }
  }

  /// Real compliance flow (agent2's AccountDeletionService): two confirms,
  /// then a full wipe — server rows + R2 objects + local cache — then
  /// sign-out. The router reacts via the auth listener.
  Future<void> _deleteAccount(BuildContext context) async {
    final me = services.authService.currentUser;
    if (me == null) return;

    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Text(
          'Everything is erased for good: your messages, photos, voice '
          'notes, and encryption keys. ${services.authService.partnerProfile?.displayName ?? 'Your partner'} '
          'keeps nothing of yours either — shared memories go with you.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep my account')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    // Typed confirmation: the erase button only enables on the exact word.
    final typedController = TextEditingController();
    final confirmed = await showAppSheet<bool>(
      context: context,
      title: 'Type DELETE to confirm',
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Confirmation',
                controller: typedController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Erase everything',
                variant: AppButtonVariant.destructive,
                expand: true,
                onPressed: typedController.text.trim().toUpperCase() == 'DELETE'
                    ? () => Navigator.of(context).pop(true)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    showAppToast(context, 'Erasing… this takes a moment.');
    final result = await AccountDeletionService(
      cache: services.localCache,
    ).deleteAccount(me.id);

    if (!context.mounted) return;
    if (result.success) {
      showAppToast(context, 'Account erased. Goodbye — and thank you.');
      // Signed out server-side; the auth listener routes to AuthScreen.
    } else {
      showAppToast(context, result.error ?? "Couldn't erase — try again or export first.");
    }
  }

  void _whatLeavesDevice(BuildContext context) {
    Navigator.of(context).push(AppRouter.fadeThrough(const _WhatLeavesDeviceScreen()));
  }
}

class _WhatLeavesDeviceScreen extends StatelessWidget {
  const _WhatLeavesDeviceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'What leaves your device'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _row(context, Icons.chat_bubble_outline_rounded, 'Your words',
              'Messages are stored on our Supabase database, protected by row-level security — only the two of you can read them. Searchable, so recaps work.'),
          _row(context, Icons.photo_outlined, 'Your photos & voice notes',
              'Encrypted on your phone before upload, stored unreadable on a private bucket. Even a bucket leak would be noise.'),
          _row(context, Icons.block_rounded, 'Never',
              'No ads. No tracking. No AI training on your memories. No third-party analytics. Ever.'),
          _row(context, Icons.download_rounded, 'Always yours',
              'One-tap export arrives with the compliance pass — and your messages already live on your device.'),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
