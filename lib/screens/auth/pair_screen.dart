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

class _PairScreenState extends State<PairScreen>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isCreator = true;
  bool _loading = false;
  String? _inviteCode;
  String? _error;

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
    _codeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _createCouple() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final code = await widget.authService.createCouple();
      setState(() => _inviteCode = code);
    } catch (e) {
      setState(() => _error = _formatError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _joinCouple() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a code');
      return;
    }
    if (code.length < 6) {
      setState(() => _error = 'Code must be 6 characters');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final success = await widget.authService.joinCouple(code);
      if (!success && mounted) {
        setState(() => _error = 'No matching code found. Ask your partner to generate a new one.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = _formatError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatError(dynamic e) {
    String msg = e.toString();
    // Clean up Supabase error messages
    msg = msg
        .replaceAll('Exception: ', '')
        .replaceAll('PostgrestException(', '')
        .replaceAll(RegExp(r',\s*statusCode:.*\)$'), '');
    if (msg.contains('duplicate key') || msg.contains('already exists')) {
      return 'You already have an active connection. Try signing out and back in.';
    }
    if (msg.contains('RLS') || msg.contains('policy')) {
      return 'Connection error. Please try again.';
    }
    return msg.length > 120 ? '${msg.substring(0, 120)}...' : msg;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Stack(
          children: [
            // Animated warm glow at top
            Positioned(
              top: -80,
              left: -40,
              right: -40,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: Opacity(
                      opacity: 0.5 + (_pulseController.value * 0.3),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(gradient: AppTheme.warmRadialGlow),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  ResponsiveWrapper(
                    maxWidth: 520,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
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
                            icon: Icon(Icons.logout_rounded,
                                size: 16,
                                color: AppTheme.onSurfaceVariant),
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
                        physics: const BouncingScrollPhysics(),
                        child: ResponsiveWrapper(
                          maxWidth: 480,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: isSmallScreen ? 12 : 20),
                              _buildHearts(isSmallScreen),
                              SizedBox(height: isSmallScreen ? 16 : 24),
                              _buildTitle(isSmallScreen),
                              SizedBox(height: isSmallScreen ? 20 : 32),
                              _buildTabs(),
                              const SizedBox(height: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeIn,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.05),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _isCreator
                                    ? _buildCreatorView()
                                    : _buildJoinerView(),
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 40),
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

  Widget _buildHearts(bool isSmall) {
    final size = isSmall ? 44.0 : 52.0;
    final iconSize = isSmall ? 22.0 : 26.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
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
          child: Icon(Icons.favorite_rounded, size: iconSize, color: Colors.white),
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
          width: size,
          height: size,
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
          child: Icon(Icons.favorite_rounded, size: iconSize, color: Colors.white),
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

  Widget _buildTitle(bool isSmall) {
    return Column(
      children: [
        Text(
          'Link Your Hearts',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isSmall ? 24 : 28,
              ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Text(
          'Connect with your partner to begin',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.onSurfaceVariant,
                fontSize: isSmall ? 14 : 16,
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
              setState(() {
                _isCreator = true;
                _error = null;
              });
            }),
          ),
          Expanded(
            child:
                _tab('Join Partner', Icons.people_rounded, !_isCreator, () {
              setState(() {
                _isCreator = false;
                _error = null;
              });
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.primaryGradient : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: active ? Colors.white : AppTheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: active ? Colors.white : AppTheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
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
          padding: const EdgeInsets.all(24),
          decoration: AppTheme.glassCard(
              opacity: 0.6, borderOpacity: 0.15, radius: 24),
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
            // Code display — responsive, wraps properly
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
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _inviteCode!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to copy',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
                Flexible(
                  child: Text(
                    'Waiting for partner to join…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.onSurfaceVariant,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // Error message
          _buildError(),
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
            onFieldSubmitted: (_) => _joinCouple(),
          ),
          const SizedBox(height: 20),
          _gradientBtn(
            'Connect ❤️',
            _loading ? null : _joinCouple,
            _loading,
          ),
          // Error message
          _buildError(),
        ],
      ),
    );
  }

  Widget _buildError() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: _error != null
          ? Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppTheme.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: Icon(Icons.close_rounded,
                          color: AppTheme.error.withValues(alpha: 0.5),
                          size: 18),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: loading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    key: ValueKey(label),
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
