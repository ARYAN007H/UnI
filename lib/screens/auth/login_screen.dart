import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/responsive_wrapper.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Stagger key — toggled on mode switch to re-trigger field animations
  bool _staggerKey = false;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  int _currentStep = 0;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  late final AnimationController _pulseController;
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _driftController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _currentStep = 0;
      _error = null;
      _staggerKey = !_staggerKey; // re-trigger staggered animations
      // Reset some fields if we switch
      if (_isLogin) {
        _confirmPasswordController.clear();
        _displayNameController.clear();
        _usernameController.clear();
      }
    });
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin && _currentStep == 1) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _error = "Passwords do not match");
        return;
      }
    }

    setState(() {
      _error = null;
      _currentStep++;
      _staggerKey = !_staggerKey;
    });
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      if (_currentStep > 0) _currentStep--;
      _staggerKey = !_staggerKey;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Extra validation for signup
    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _error = "Passwords do not match");
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await widget.authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          username: _usernameController.text.trim(),
        );
        // Show verification prompt after successful signup
        if (mounted && widget.authService.justSignedUp) {
          _showVerificationPrompt();
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showVerificationPrompt() {
    widget.authService.clearJustSignedUp();
    bool sending = false;
    bool sent = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15)),
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
              const SizedBox(height: 24),
              // Celebration icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to U&i! 🎉',
                style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please verify your email within 24 hours.\nYou can start using the app right away!',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 8),
              // Email chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _emailController.text.trim(),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(height: 28),
              // Send verification link button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: sent ? null : AppTheme.primaryGradient,
                  color: sent ? AppTheme.success.withValues(alpha: 0.12) : null,
                  borderRadius: BorderRadius.circular(14),
                  border: sent
                      ? Border.all(color: AppTheme.success.withValues(alpha: 0.3))
                      : null,
                  boxShadow: sent
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ElevatedButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          setSheetState(() {
                            sending = true;
                            sent = false;
                          });
                          try {
                            await widget.authService.sendVerificationEmail();
                            setSheetState(() {
                              sending = false;
                              sent = true;
                            });
                          } catch (_) {
                            setSheetState(() => sending = false);
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          sent ? Icons.check_circle_rounded : Icons.email_rounded,
                          color: sent ? AppTheme.success : Colors.white,
                          size: 20,
                        ),
                  label: Text(
                    sent ? 'Link Sent!' : 'Send Verification Link',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: sent ? AppTheme.success : Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Skip button
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "I'll do it later",
                  style: TextStyle(
                    color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.surfaceGradient),
        child: Stack(
          children: [
            // Ambient drifting + pulsing background glow
            Positioned(
              top: -100,
              left: -100,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseController, _driftController]),
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset((_driftController.value - 0.5) * 60, (_driftController.value - 0.5) * 40),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary.withValues(alpha: 0.15 + (_pulseController.value * 0.1)),
                        boxShadow: [
                          BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseController, _driftController]),
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(-(_driftController.value - 0.5) * 40, -(_driftController.value - 0.5) * 60),
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.secondary.withValues(alpha: 0.15 + ((1.0 - _pulseController.value) * 0.1)),
                        boxShadow: [
                          BoxShadow(color: AppTheme.secondary.withValues(alpha: 0.2), blurRadius: 120, spreadRadius: 50),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              left: MediaQuery.of(context).size.width * 0.2,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.tertiary.withValues(alpha: 0.1 + (_pulseController.value * 0.1)),
                      boxShadow: [
                        BoxShadow(color: AppTheme.tertiary.withValues(alpha: 0.15), blurRadius: 80, spreadRadius: 30),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ResponsiveWrapper(
                      maxWidth: 480,
                      padding: const EdgeInsets.only(
                        left: 28,
                        right: 28,
                        bottom: 40,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 40),
                          _buildFormCard(),
                          const SizedBox(height: 24),
                          _buildToggle(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 1.seconds),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Pulsing Heart Logo
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.05),
              child: child,
            );
          },
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
        
        const SizedBox(height: 24),
        
        ShaderMask(
          shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
          child: Text(
            'U&i',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 8),
        
        Text(
          'Your private space together ❤️',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.onSurfaceVariant,
              ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: AppTheme.glassCard(opacity: 0.7, borderOpacity: 0.15, radius: 28).copyWith(
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.1), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: Form(
            key: _formKey,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Align(
                      key: ValueKey('$_isLogin-$_currentStep'),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentStep > 0) ...[
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                              color: AppTheme.onSurfaceVariant,
                              onPressed: _previousStep,
                              padding: const EdgeInsets.only(top: 4, right: 12),
                              constraints: const BoxConstraints(),
                              alignment: Alignment.topCenter,
                            ),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isLogin ? 'Welcome back' : 'Create your account',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLogin
                                      ? 'Sign in to continue your journey'
                                      : 'Start your private love story',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Animated Error Banner
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: _error != null
                        ? Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: AppTheme.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Fields wrapper for staggered animations
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: _isLogin ? _buildLoginFields() : _buildSignUpFields(),
                  ),

                  const SizedBox(height: 32),

                  _buildGradientButton(
                    label: _isLogin 
                        ? (_currentStep == 0 ? 'Continue' : 'Sign In')
                        : (_currentStep < 2 ? 'Continue' : 'Create Account'),
                    loading: _loading,
                    onPressed: _loading ? null : (_isLogin 
                        ? (_currentStep == 0 ? _nextStep : _submit)
                        : (_currentStep < 2 ? _nextStep : _submit)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildLoginFields() {
    return Column(
      key: ValueKey('login_fields_${_currentStep}_$_staggerKey'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentStep == 0)
          _AnimatedTextField(
            controller: _emailController,
            hint: 'Email address',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        if (_currentStep == 1)
          _AnimatedTextField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_rounded,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppTheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              return null;
            },
          ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }

  Widget _buildSignUpFields() {
    return Column(
      key: ValueKey('signup_fields_${_currentStep}_$_staggerKey'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentStep == 0)
          _AnimatedTextField(
            controller: _emailController,
            hint: 'Email address',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        
        if (_currentStep == 1) ...[
          _AnimatedTextField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_rounded,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppTheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 6) return 'Min 6 characters';
              return null;
            },
          ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          _AnimatedTextField(
            controller: _confirmPasswordController,
            hint: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppTheme.onSurfaceVariant,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        ],

        if (_currentStep == 2) ...[
          _AnimatedTextField(
            controller: _displayNameController,
            hint: 'What should we call you?',
            icon: Icons.person_rounded,
            capitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter your name' : null,
          ).animate().fadeIn(delay: 50.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          _AnimatedTextField(
            controller: _usernameController,
            hint: 'Pick a unique username',
            icon: Icons.alternate_email_rounded,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Pick a username' : null,
          ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        ],
      ],
    );
  }

  Widget _buildGradientButton({
    required String label,
    required bool loading,
    VoidCallback? onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: loading ? 0.1 : 0.3),
            blurRadius: loading ? 8 : 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  key: ValueKey(label),
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: -0.05, end: 0.05, duration: 2.seconds);
  }

  Widget _buildToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            key: ValueKey(_isLogin),
            _isLogin ? "Don't have an account? " : 'Already have an account? ',
            style: TextStyle(
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        GestureDetector(
          onTap: _toggleMode,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ShaderMask(
                key: ValueKey(_isLogin),
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: Text(
                  _isLogin ? 'Sign Up' : 'Sign In',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }
}

/// A custom text field that animates its border and subtly scales up when focused.
class _AnimatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AnimatedTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  State<_AnimatedTextField> createState() => _AnimatedTextFieldState();
}

class _AnimatedTextFieldState extends State<_AnimatedTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      transform: Matrix4.diagonal3Values(_isFocused ? 1.02 : 1.0, _isFocused ? 1.02 : 1.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (_isFocused)
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 2,
              )
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: AnimatedTheme(
              data: Theme.of(context).copyWith(
                iconTheme: IconThemeData(
                  color: _isFocused ? AppTheme.primary : AppTheme.onSurfaceVariant,
                ),
              ),
              child: Icon(widget.icon, size: 22),
            ),
            suffixIcon: widget.suffixIcon,
            filled: true,
            fillColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: AppTheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: widget.keyboardType,
          textCapitalization: widget.capitalization,
          obscureText: widget.obscure,
          validator: widget.validator,
          style: TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
