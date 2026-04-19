import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: widget.authService.signOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 40),
                          _buildToggle(),
                          const SizedBox(height: 32),
                          _isCreator ? _buildCreatorView() : _buildJoinerView(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 36, color: AppTheme.primary)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms),
            const SizedBox(width: 8),
            Icon(Icons.favorite, size: 36, color: AppTheme.secondary)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms, delay: 300.ms),
          ],
        ),
        const SizedBox(height: 20),
        Text('Link Your Hearts', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700))
            .animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 8),
        Text('Connect with your partner to start chatting',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center)
            .animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _tab('Create Link', Icons.add_link_rounded, _isCreator, () => setState(() { _isCreator = true; _error = null; }))),
          Expanded(child: _tab('Join Partner', Icons.link_rounded, !_isCreator, () => setState(() { _isCreator = false; _error = null; }))),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _tab(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(gradient: active ? AppTheme.primaryGradient : null, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : AppTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.white : AppTheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.3)),
          ),
          child: child,
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _buildCreatorView() {
    return _glassCard(
      child: Column(children: [
        if (_inviteCode == null) ...[
          Text('Generate a unique code and share it with your partner.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _gradientBtn('Generate Code', _loading ? null : _createCouple, _loading),
        ] else ...[
          Text('Share this code with your partner:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: _inviteCode!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!'))); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 20)]),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_inviteCode!, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 6, color: Colors.white)),
                const SizedBox(width: 12),
                const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
              ]),
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut).fadeIn(),
          const SizedBox(height: 16),
          Text('Tap to copy • Waiting for partner…', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant)),
        ],
        if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))],
      ]),
    );
  }

  Widget _buildJoinerView() {
    return _glassCard(
      child: Column(children: [
        Text('Enter the code your partner shared:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextFormField(
          controller: _codeController,
          decoration: const InputDecoration(hintText: 'Enter 6-digit code', prefixIcon: Icon(Icons.key_rounded)),
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 4),
          maxLength: 6,
        ),
        const SizedBox(height: 20),
        _gradientBtn('Connect', _loading ? null : _joinCouple, _loading),
        if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13))],
      ]),
    );
  }

  Widget _gradientBtn(String label, VoidCallback? onPressed, bool loading) {
    return SizedBox(
      width: double.infinity, height: 54,
      child: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))]),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          child: loading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }
}
