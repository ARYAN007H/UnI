import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/responsive_wrapper.dart';

class PairScreen extends StatefulWidget {
  final AuthService authService;
  const PairScreen({super.key, required this.authService});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _codeController = TextEditingController();
  bool _isCreator = true;
  bool _loading = false;
  String? _inviteCode;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createCouple() async {
    setState(() { _loading = true; _error = null; });
    try {
      final code = await widget.authService.createCouple();
      setState(() => _inviteCode = code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinCouple() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final success = await widget.authService.joinCouple(code);
      if (!success && mounted) {
        setState(() => _error = 'Invalid or expired invite code');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Stack(
          children: [
            // Warm glow at top
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              child: Container(
                height: 300,
                decoration: BoxDecoration(gradient: AppTheme.warmRadialGlow),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  ResponsiveWrapper(
                    maxWidth: 520,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 48),
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppTheme.primaryGradient.createShader(b),
                            child: Text(
                              'U&i',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: widget.authService.signOut,
                            icon:
                                Icon(Icons.logout_rounded, size: 16, color: AppTheme.onSurfaceVariant),
                            label: Text('Logout',
                                style: TextStyle(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ResponsiveWrapper(
                          maxWidth: 480,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHearts(),
                              const SizedBox(height: 24),
                              _buildTitle(),
                              const SizedBox(height: 32),
                              _buildTabs(),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _isCreator
                                    ? _buildCreatorView()
                                    : _buildJoinerView(),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHearts() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child:
              const Icon(Icons.favorite_rounded, size: 26, color: Colors.white),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.1, 1.1),
              duration: 1500.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(width: 12),
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.secondary,
            boxShadow: [
              BoxShadow(
                color: AppTheme.secondary.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child:
              const Icon(Icons.favorite_rounded, size: 26, color: Colors.white),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.1, 1.1),
              duration: 1500.ms,
              delay: 400.ms,
              curve: Curves.easeInOut,
            ),
      ],
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Link Your Hearts',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Connect with your partner to begin',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tab('Create Link', Icons.link_rounded, _isCreator, () {
              setState(() { _isCreator = true; _error = null; });
            }),
          ),
          Expanded(
            child: _tab('Join Partner', Icons.people_rounded, !_isCreator, () {
              setState(() { _isCreator = false; _error = null; });
            }),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _tab(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: active ? Colors.white : AppTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: active ? Colors.white : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child, Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: AppTheme.glassCard(opacity: 0.6, borderOpacity: 0.15, radius: 24),
          child: child,
        ),
      ),
    );
  }

  Widget _buildCreatorView() {
    return _glassCard(
      key: const ValueKey('creator'),
      child: Column(
        children: [
          if (_inviteCode == null) ...[
            Icon(Icons.link_rounded, size: 32, color: AppTheme.secondary),
            const SizedBox(height: 16),
            Text(
              'Generate a unique code and share it with your partner.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _gradientBtn(
              'Generate Code',
              _loading ? null : _createCouple,
              _loading,
            ),
          ] else ...[
            Icon(Icons.check_circle_rounded,
                size: 28, color: AppTheme.success),
            const SizedBox(height: 12),
            Text(
              'Share this code with your partner',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _inviteCode!));
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.copy_rounded,
                            size: 16, color: AppTheme.onSurface),
                        const SizedBox(width: 8),
                        const Text('Code copied to clipboard!'),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _inviteCode!,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.copy_rounded,
                        color: Colors.white.withValues(alpha: 0.7), size: 20),
                  ],
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                )
                .fadeIn(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Waiting for partner to join…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(
                    color: AppTheme.primary, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinerView() {
    return _glassCard(
      key: const ValueKey('joiner'),
      child: Column(
        children: [
          Icon(Icons.people_rounded, size: 32, color: AppTheme.secondary),
          const SizedBox(height: 16),
          Text(
            'Enter the code your partner shared',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: 'Enter 6-digit code',
              prefixIcon: Icon(Icons.key_rounded,
                  size: 20, color: AppTheme.onSurfaceVariant),
              filled: true,
              fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
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
              counterText: '',
            ),
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
            maxLength: 6,
          ),
          const SizedBox(height: 20),
          _gradientBtn(
            'Connect ❤️',
            _loading ? null : _joinCouple,
            _loading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(
                    color: AppTheme.primary, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  Widget _gradientBtn(String label, VoidCallback? onPressed, bool loading) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Container(
        decoration: AppTheme.gradientButton(),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
