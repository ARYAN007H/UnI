import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/responsive_wrapper.dart';

/// Full-screen blocker shown when the 24-hour email verification
/// grace period has expired.
class VerifyEmailScreen extends StatefulWidget {
  final AuthService authService;
  const VerifyEmailScreen({super.key, required this.authService});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  bool _sending = false;
  bool _sent = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    setState(() {
      _sending = true;
      _sent = false;
    });
    try {
      await widget.authService.sendVerificationEmail();
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authService.currentUser?.email ?? 'your email';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Stack(
          children: [
            // Ambient glow
            Positioned(
              top: -60,
              left: -40,
              right: -40,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.12),
                    child: Opacity(
                      opacity: 0.5 + (_pulseController.value * 0.3),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  height: 350,
                  decoration: BoxDecoration(
                    gradient: AppTheme.warmRadialGlow,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: ResponsiveWrapper(
                maxWidth: 480,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Mail icon with glass background
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primary.withValues(alpha: 0.15),
                                AppTheme.secondary.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.mark_email_unread_rounded,
                            size: 48,
                            color: AppTheme.primaryLight,
                          ),
                        ),
                      ),
                    ).animate().scale(
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                        ),

                    const SizedBox(height: 32),

                    // Title
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppTheme.primaryGradient.createShader(b),
                      child: Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.15, end: 0),

                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      'Your 24-hour grace period has ended.\nPlease verify your email to continue using U&i.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ).animate().fadeIn(delay: 350.ms),

                    const SizedBox(height: 8),

                    // Email chip
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email_rounded,
                              size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              email,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 450.ms),

                    const SizedBox(height: 40),

                    // Send verification button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: _sent ? null : AppTheme.primaryGradient,
                        color: _sent
                            ? AppTheme.success.withValues(alpha: 0.15)
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        border: _sent
                            ? Border.all(
                                color:
                                    AppTheme.success.withValues(alpha: 0.3))
                            : null,
                        boxShadow: _sent
                            ? null
                            : [
                                BoxShadow(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed:
                            _sending ? null : _sendLink,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _sent
                                    ? Icons.check_circle_rounded
                                    : Icons.send_rounded,
                                color: _sent
                                    ? AppTheme.success
                                    : Colors.white,
                                size: 20,
                              ),
                        label: Text(
                          _sent
                              ? 'Verification Link Sent!'
                              : 'Send Verification Link',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _sent
                                ? AppTheme.success
                                : Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),

                    if (_sent) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Check your inbox and click the link to verify.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w500,
                            ),
                      ).animate().fadeIn(duration: 400.ms),
                    ],

                    const Spacer(flex: 2),

                    // Sign out option
                    TextButton.icon(
                      onPressed: () => widget.authService.signOut(),
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      label: Text(
                        'Sign out',
                        style: TextStyle(
                          color:
                              AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ).animate().fadeIn(delay: 700.ms),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
