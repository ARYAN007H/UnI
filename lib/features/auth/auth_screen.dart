import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';

/// Sign-in (docs/design/auth.md): Google primary, email-link fallback,
/// email+password as the working default until Google is configured in the
/// Supabase/Play consoles. One decision per screen; no verification wall.
class AuthScreen extends StatefulWidget {
  final AuthService authService;

  const AuthScreen({super.key, required this.authService});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordMode = true;
  bool _linkSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toast(String message) => showAppToast(context, message);

  Future<void> _withBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInEmail() => _withBusy(() async {
        try {
          await widget.authService.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        } on AuthException catch (e) {
          // New here? Sign them up — one field, no separate signup screen.
          if (e.message.toLowerCase().contains('invalid login')) {
            await _signUpEmail();
          } else {
            _toast(e.message);
          }
        } catch (_) {
          _toast("Couldn't sign in — check your connection and try again.");
        }
      });

  Future<void> _signUpEmail() => _withBusy(() async {
        try {
          final email = _emailController.text.trim();
          await widget.authService.signUp(
            email: email,
            password: _passwordController.text,
            username: email.split('@').first,
            displayName: email.split('@').first,
          );
          // Router reacts via authService listener — nothing to push here.
        } on AuthException catch (e) {
          _toast(e.message);
        } catch (_) {
          _toast("Couldn't sign up — check your connection and try again.");
        }
      });

  Future<void> _sendMagicLink() => _withBusy(() async {
        try {
          await Supabase.instance.client.auth.signInWithOtp(
            email: _emailController.text.trim(),
            emailRedirectTo: kIsWeb ? null : 'uandi://login',
          );
          if (mounted) setState(() => _linkSent = true);
        } on AuthException catch (e) {
          _toast(e.message);
        } catch (_) {
          _toast("Couldn't send the link — try again.");
        }
      });

  Future<void> _signInGoogle() => _withBusy(() async {
        try {
          final google = await GoogleSignIn().signIn();
          if (google == null) return; // user cancelled
          final auth = await google.authentication;
          final idToken = auth.idToken;
          if (idToken == null) {
            _toast("Google sign-in didn't return a token — use email.");
            return;
          }
          await Supabase.instance.client.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
          );
        } catch (e) {
          debugPrint('[Auth] google sign-in failed: $e');
          _toast("Google sign-in isn't configured yet — use email for now.");
        }
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xxl * 2),
                _brand(context),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: _signInGoogle,
                      loading: _busy && !_passwordMode,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: _passwordMode
                          ? 'Use an email link instead'
                          : 'Use email & password instead',
                      variant: AppButtonVariant.ghost,
                      onPressed: () =>
                          setState(() => _passwordMode = !_passwordMode),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_linkSent)
                      Text(
                        'Check your inbox — the link works for 1 hour.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else ...[
                      AppTextField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_passwordMode) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          label: 'Password',
                          controller: _passwordController,
                          obscure: true,
                          onSubmitted: (_) => _signInEmail(),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: _passwordMode
                            ? 'Continue with email'
                            : 'Send the link',
                        expand: true,
                        onPressed: _emailController.text.contains('@')
                            ? (_passwordMode ? _signInEmail : _sendMagicLink)
                            : null,
                        loading: _busy,
                      ),
                    ],
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg, top: AppSpacing.xxl),
                  child: Column(
                    children: [
                      _TrustLine('No ads. No tracking. Your words stay yours.'),
                      SizedBox(height: AppSpacing.xs),
                      _TrustLine('18+ only · Delete your account anytime'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.onSurface,
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
            ],
          ).createShader(bounds),
          child: Text(
            'U&i',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppText.secondary(context, 'Your private space, together.'),
      ],
    );
  }
}

class _TrustLine extends StatelessWidget {
  final String text;
  const _TrustLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      textAlign: TextAlign.center,
    );
  }
}
