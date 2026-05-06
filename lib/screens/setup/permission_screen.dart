import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/foundation.dart';
import '../../config/theme.dart';
import '../../services/backup_service.dart';
import '../../services/permission_service.dart';

/// Beautiful first-launch permission setup screen.
/// Walks the user through granting permissions one by one.
class PermissionScreen extends StatefulWidget {
  final PermissionService permissionService;
  final BackupService backupService;
  final VoidCallback onComplete;

  const PermissionScreen({
    super.key,
    required this.permissionService,
    required this.backupService,
    required this.onComplete,
  });

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  int _currentStep = 0;
  bool _backupToggle = false;

  late final _steps = [
    _PermStep(
      icon: Icons.notifications_rounded,
      emoji: '🔔',
      title: 'Stay Connected',
      subtitle: 'Get notified when your partner sends a message',
      permType: 'notifications',
    ),
    _PermStep(
      icon: Icons.camera_alt_rounded,
      emoji: '📸',
      title: 'Capture Moments',
      subtitle: 'Take photos and videos to share together',
      permType: 'camera',
    ),
    _PermStep(
      icon: Icons.photo_library_rounded,
      emoji: '🖼️',
      title: 'Share Memories',
      subtitle: 'Access your gallery to send photos and videos',
      permType: 'photos',
    ),
    _PermStep(
      icon: Icons.mic_rounded,
      emoji: '🎙️',
      title: 'Voice Messages',
      subtitle: 'Record and send voice notes to each other',
      permType: 'microphone',
    ),
    _PermStep(
      icon: Icons.folder_rounded,
      emoji: '💾',
      title: kIsWeb ? 'Offline Storage' : 'Save & Backup',
      subtitle: kIsWeb ? 'Keep your chat history safely stored in this browser' : 'Store media and backup your chat history',
      permType: 'storage',
    ),
  ];

  Future<void> _requestPermission(String type) async {
    HapticFeedback.lightImpact();
    switch (type) {
      case 'notifications':
        await widget.permissionService.requestNotifications();
        break;
      case 'camera':
        await widget.permissionService.requestCamera();
        break;
      case 'photos':
        await widget.permissionService.requestPhotos();
        break;
      case 'microphone':
        await widget.permissionService.requestMicrophone();
        break;
      case 'storage':
        await widget.permissionService.requestStorage();
        break;
    }
    _nextStep();
  }

  void _nextStep() {
    if (_currentStep < _steps.length) {
      setState(() => _currentStep++);
    }
  }

  Future<void> _setupBackup() async {
    if (_backupToggle) {
      final success = await widget.backupService.signIn();
      if (success) {
        await widget.permissionService.setBackupEnabled(true);
      }
    }
    await widget.permissionService.completeSetup();
    widget.onComplete();
  }


  @override
  Widget build(BuildContext context) {
    final isBackupStep = _currentStep >= _steps.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Progress
                _buildProgress(),
                const Spacer(flex: 2),
                // Content
                if (isBackupStep)
                  _buildBackupStep()
                else
                  _buildPermissionStep(_steps[_currentStep]),
                const Spacer(flex: 3),
                // Actions
                if (isBackupStep)
                  _buildBackupActions()
                else
                  _buildPermissionActions(_steps[_currentStep]),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress() {
    final total = _steps.length + 1; // +1 for backup
    return Row(
      children: List.generate(total, (i) {
        final isActive = i <= _currentStep;
        return Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isActive
                  ? AppTheme.primary
                  : AppTheme.outline.withValues(alpha: 0.2),
            ),
          ),
        );
      }),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildPermissionStep(_PermStep step) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.15),
                AppTheme.secondary.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Center(
            child: Text(step.emoji, style: const TextStyle(fontSize: 44)),
          ),
        )
            .animate(key: ValueKey(_currentStep))
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 300.ms),
        const SizedBox(height: 32),
        Text(
          step.title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
          textAlign: TextAlign.center,
        ).animate(key: ValueKey('t$_currentStep')).fadeIn(duration: 300.ms),
        const SizedBox(height: 12),
        Text(
          step.subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ).animate(key: ValueKey('s$_currentStep')).fadeIn(delay: 100.ms, duration: 300.ms),
      ],
    );
  }

  Widget _buildPermissionActions(_PermStep step) {
    return Column(
      children: [
        // Allow button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => _requestPermission(step.permType),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Allow',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Skip
        TextButton(
          onPressed: _nextStep,
          child: Text(
            'Maybe Later',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppTheme.secondary.withValues(alpha: 0.15),
                AppTheme.tertiary.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: const Center(
            child: Text('☁️', style: TextStyle(fontSize: 44)),
          ),
        ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.elasticOut,
            ),
        const SizedBox(height: 32),
        Text(
          'Google Drive Backup',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 12),
        Text(
          'Back up your chats and media to Google Drive.\nRestore anytime on a new device.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
        const SizedBox(height: 28),
        // Toggle
        ListenableBuilder(
          listenable: widget.backupService,
          builder: (_, __) => GestureDetector(
            onTap: () => setState(() => _backupToggle = !_backupToggle),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: _backupToggle
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _backupToggle
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : AppTheme.outline.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    color: _backupToggle
                        ? AppTheme.primary
                        : AppTheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Auto Backup',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          'Uses Google Drive app storage',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _backupToggle,
                    onChanged: (v) => setState(() => _backupToggle = v),
                    activeTrackColor: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _setupBackup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _backupToggle ? 'Sign In & Continue' : 'Get Started',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PermStep {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final String permType;

  const _PermStep({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.permType,
  });
}
