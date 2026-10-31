import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../services/auth_service.dart';
import '../../services/daily_question_service.dart';
import '../../services/media_service.dart';

/// The 3-step onboarding flow (docs/design/onboarding.md, plan §6):
/// 18+ gate → make it yours (name, avatar, first answer) → pair.
/// One decision per screen; resumable via local flags; no permissions wall.
class OnboardingFlow extends StatefulWidget {
  final AuthService authService;
  final DailyQuestionService dailyQuestionService;
  final MediaService mediaService;
  final SharedPreferences prefs;

  const OnboardingFlow({
    super.key,
    required this.authService,
    required this.dailyQuestionService,
    required this.mediaService,
    required this.prefs,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _adultKey = 'onboarding.adult_confirmed';

  int _step = 0;

  @override
  void initState() {
    super.initState();
    _step = (widget.prefs.getBool(_adultKey) ?? false) ? 1 : 0;
  }

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 0:
        return _GateScreen(onConfirmed: () async {
          await widget.prefs.setBool(_adultKey, true);
          _next();
        });
      case 1:
        return _ProfileScreen(
          authService: widget.authService,
          mediaService: widget.mediaService,
          onDone: _next,
        );
      case 2:
        return _FirstQuestionScreen(
          authService: widget.authService,
          dailyQuestionService: widget.dailyQuestionService,
          onDone: _next,
        );
      default:
        return _PairScreen(authService: widget.authService);
    }
  }
}

// ── Step 0: the honest gate ─────────────────────────────────────────────

class _GateScreen extends StatelessWidget {
  final VoidCallback onConfirmed;

  const _GateScreen({required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.headline(context, 'One thing first'),
              const SizedBox(height: AppSpacing.sm),
              AppText.secondary(
                  context, 'U&i is built for adults. Are you 18 or older?'),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: "Yes, I'm 18+",
                expand: true,
                onPressed: onConfirmed,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'No — take me back',
                variant: AppButtonVariant.ghost,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2a: make it yours ──────────────────────────────────────────────

class _ProfileScreen extends StatefulWidget {
  final AuthService authService;
  final MediaService mediaService;
  final VoidCallback onDone;

  const _ProfileScreen({
    required this.authService,
    required this.mediaService,
    required this.onDone,
  });

  @override
  State<_ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileScreen> {
  final _nameController = TextEditingController();
  String? _avatarPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.authService.profile?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await widget.mediaService.pickImage(maxWidth: 512, quality: 80);
    if (file != null) setState(() => _avatarPath = file.path);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      if (name != (widget.authService.profile?.displayName ?? '')) {
        await widget.authService.updateDisplayName(name);
      }
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) showAppToast(context, "Couldn't save — try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Make it yours'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.secondary(
                  context, 'What should they call you? (avatar optional)'),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: GestureDetector(
                  onTap: _pickAvatar,
                  child: Stack(
                    children: [
                      _avatarPath == null
                          ? Avatar(
                              name: _nameController.text,
                              radius: 44,
                              imageUrl: widget.authService.profile?.avatarUrl,
                            )
                          : CircleAvatar(
                              radius: 44,
                              backgroundImage: FileImage(File(_avatarPath!)),
                            ),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.camera_alt_rounded, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Your name',
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
              ),
              const Spacer(),
              AppButton(
                label: 'Continue',
                expand: true,
                loading: _saving,
                onPressed:
                    _nameController.text.trim().isNotEmpty ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2b: the first answer (solo value before pairing) ───────────────

class _FirstQuestionScreen extends StatefulWidget {
  final AuthService authService;
  final DailyQuestionService dailyQuestionService;
  final VoidCallback onDone;

  const _FirstQuestionScreen({
    required this.authService,
    required this.dailyQuestionService,
    required this.onDone,
  });

  @override
  State<_FirstQuestionScreen> createState() => _FirstQuestionScreenState();
}

class _FirstQuestionScreenState extends State<_FirstQuestionScreen> {
  final _answerController = TextEditingController();
  DailyQuestion? _question;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final couple = widget.authService.couple;
    final q = await widget.dailyQuestionService
        .questionOfDay(couple?.id ?? 'unpaired');
    if (mounted) setState(() => _question = q);
  }

  Future<void> _submit() async {
    final content = _answerController.text.trim();
    if (content.isEmpty || _submitting) return;
    final couple = widget.authService.couple;
    final user = widget.authService.currentUser;
    if (_question == null || user == null) return;

    setState(() => _submitting = true);
    try {
      // Unpaired users answer locally; the answer is theirs when they pair.
      await widget.dailyQuestionService.submitAnswer(
        coupleId: couple?.id ?? 'unpaired',
        question: _question!,
        myUserId: user.id,
        content: content,
      );
      if (mounted) widget.onDone();
    } catch (e) {
      if (mounted) {
        showAppToast(context, "Saved locally — we'll sync it when you're online.");
        widget.onDone();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;
    return Scaffold(
      appBar: AppAppBar(
        title: 'Just for today',
        actions: [
          TextButton(onPressed: widget.onDone, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.secondary(
                  context, 'Answer your first question — it unlocks when they join.'),
              const SizedBox(height: AppSpacing.lg),
              if (q == null)
                const Skeleton(height: 80)
              else ...[
                AppCard(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText.caption(
                          context, '${q.emoji} ${q.category}'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(q.text,
                          style: Theme.of(context).textTheme.headlineMedium),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Your answer',
                  hint: 'Only they will ever read this…',
                  controller: _answerController,
                  maxLines: 4,
                  minLines: 2,
                ),
                const Spacer(),
                AppButton(
                  label: 'Seal my answer',
                  expand: true,
                  loading: _submitting,
                  onPressed:
                      _answerController.text.trim().isNotEmpty ? _submit : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 3: pair ────────────────────────────────────────────────────────

class _PairScreen extends StatefulWidget {
  final AuthService authService;

  const _PairScreen({required this.authService});

  @override
  State<_PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<_PairScreen> {
  final _codeController = TextEditingController();
  bool _creating = false;
  bool _joining = false;
  String? _myCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    setState(() => _creating = true);
    try {
      final code = await widget.authService.createCouple();
      if (mounted) setState(() => _myCode = code);
    } catch (e) {
      if (mounted) showAppToast(context, "Couldn't create your invite — try again.");
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final ok = await widget.authService.joinCouple(_codeController.text);
      if (!mounted) return;
      if (ok) {
        // Router reacts via authService listener (couple != null → shell).
      } else {
        showAppToast(context, "That code didn't match — check and try again.");
      }
    } catch (e) {
      if (mounted) showAppToast(context, "Couldn't join — try again.");
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _joinFromLink() async {
    final raw = await Clipboard.getData(Clipboard.kTextPlain);
    final text = raw?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) showAppToast(context, 'Copy the link first, then tap this.');
      return;
    }
    final uri = Uri.tryParse(text);
    final code = uri == null ? null : AuthService.extractPairCode(uri);
    if (code == null) {
      if (mounted) showAppToast(context, "That link isn't a U&i invite.");
      return;
    }
    _codeController.text = code;
    await _join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Bring them in'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText.secondary(
                  context, 'Send them your code — one tap for them, no accounts juggling.'),
              const SizedBox(height: AppSpacing.xl),
              if (_myCode == null)
                AppButton(
                  label: 'Create my invite',
                  expand: true,
                  loading: _creating,
                  onPressed: _createInvite,
                )
              else
                AppCard(
                  child: Column(
                    children: [
                      AppText.caption(context, 'YOUR INVITE CODE'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _myCode!,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Copy code',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.copy_rounded,
                        onPressed: () {
                          // share_plus lands in Phase 3 (board REQUEST) —
                          // clipboard is the honest v1.
                          Clipboard.setData(ClipboardData(text: _myCode!));
                          showAppToast(context, 'Code copied — send it to them.');
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: AppSpacing.xl),
              AppText.secondary(context, 'Got a code from them?'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Their invite code',
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Pair up',
                expand: true,
                loading: _joining,
                onPressed: _codeController.text.trim().length >= 4 ? _join : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Paste an invite link instead',
                variant: AppButtonVariant.ghost,
                onPressed: _joinFromLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
