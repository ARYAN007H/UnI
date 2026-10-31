import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../services/crypto_service.dart';

/// One-time per-device setup after pairing (agent2 §7.5): arm the couple
/// media key, show the recovery code ONCE, escrow it server-side.
/// Re-openable from Settings for anyone who skipped it.
class SecureMediaScreen extends StatefulWidget {
  final AuthService authService;
  final SharedPreferences prefs;
  final bool skippable;

  const SecureMediaScreen({
    super.key,
    required this.authService,
    required this.prefs,
    this.skippable = true,
  });

  static const flagPrefix = 'secure_media_done_';

  @override
  State<SecureMediaScreen> createState() => _SecureMediaScreenState();
}

class _SecureMediaScreenState extends State<SecureMediaScreen> {
  final CryptoService _crypto = CryptoService();
  String? _recoveryCode;
  String _status = 'Preparing your private key…';
  bool _busy = true;
  bool _escrowing = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  Future<void> _arm() async {
    final user = widget.authService.currentUser;
    final couple = widget.authService.couple;
    if (user == null || couple == null) {
      setState(() {
        _busy = false;
        _status = 'Pair first — encryption arms once you two are connected.';
      });
      return;
    }
    try {
      await _crypto.ensureDeviceKeypair(user.id);
      final armed = await _crypto.hasCoupleKey(couple.id, user.id);
      if (armed) {
        setState(() {
          _busy = false;
          _status = 'Media encryption is already on for this device.';
        });
        return;
      }
      setState(() {
        _recoveryCode = CryptoService.generateRecoveryCode();
        _busy = false;
        _status = 'Write this down. It is shown ONCE.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = "Couldn't prepare encryption — try again from Settings.";
      });
    }
  }

  Future<void> _confirmSaved() async {
    final user = widget.authService.currentUser;
    final couple = widget.authService.couple;
    final code = _recoveryCode;
    if (user == null || couple == null || code == null) return;
    setState(() => _escrowing = true);
    try {
      await _crypto.createRecoveryEscrow(
        coupleId: couple.id,
        myUserId: user.id,
        recoveryCode: code,
      );
      await widget.prefs.setBool('${SecureMediaScreen.flagPrefix}${user.id}', true);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _escrowing = false);
        showAppToast(context, "Couldn't seal the backup — try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _recoveryCode;
    return PopScope(
      canPop: widget.skippable && !_escrowing,
      child: Scaffold(
        appBar: AppAppBar(
          title: 'Secure your memories',
          leading: widget.skippable && !_escrowing
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                )
              : null,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppText.secondary(
                    context,
                    'Photos and voice notes are encrypted so only the two of '
                    'you can open them. This code re-arms them on a new phone.'),
                const SizedBox(height: AppSpacing.xl),
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else if (code == null)
                  AppCard(
                      child: Text(_status,
                          style: Theme.of(context).textTheme.bodyLarge))
                else ...[
                  AppCard(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Column(
                      children: [
                        AppText.caption(context, 'RECOVERY CODE'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          code,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: 'Copy',
                          variant: AppButtonVariant.ghost,
                          icon: Icons.copy_rounded,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            showAppToast(context, 'Copied. Save it somewhere safe.');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppText.secondary(
                      context,
                      'If you lose this code, a new phone can never decrypt '
                      'your old media. There is no reset — by design.'),
                  const Spacer(),
                  AppButton(
                    label: "I've saved it — turn on encryption",
                    expand: true,
                    loading: _escrowing,
                    onPressed: _confirmSaved,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
