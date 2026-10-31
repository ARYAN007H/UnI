import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/router/app_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../settings/settings_screen.dart';
import '../shell/home_shell.dart';
import 'home_viewmodel.dart';

/// Home — "Where are we, right now?" (docs/design/home.md).
/// Presence card first, the daily ritual second, everything else whispers.
class HomeScreen extends StatefulWidget {
  final ServiceBundle services;
  final ValueChanged<AppTab> onOpenTab;

  const HomeScreen({super.key, required this.services, required this.onOpenTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = HomeViewModel(
      authService: widget.services.authService,
      chatService: widget.services.chatService,
      dailyQuestionService: widget.services.dailyQuestionService,
    );
    _vm.loadQuestion();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, widget.services.authService, widget.services.chatService, widget.services.presenceService]),
      builder: (context, _) {
        return Scaffold(
          appBar: _appBar(context),
          body: RefreshIndicator(
            onRefresh: _vm.loadQuestion,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _presenceCard(context),
                const SizedBox(height: AppSpacing.md),
                _questionCard(context),
                if (_vm.nextPlan != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _countdown(context),
                ],
                if (_vm.unreadFromPartner > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _unreadLine(context),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final now = DateTime.now();
    final date = '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)} ${now.year}';
    return AppAppBar(
      title: date,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            AppRouter.slideUp(
              SettingsScreen(services: widget.services),
              settings: const RouteSettings(name: RouteNames.settings),
            ),
          ),
        ),
      ],
    );
  }

  Widget _presenceCard(BuildContext context) {
    final partner = _vm.partner;
    final name = partner?.displayName ?? 'Them';
    final online = _vm.partnerId != null
        ? widget.services.presenceService.partnerOnline
        : null;
    final ext = Theme.of(context).extension<UAndiThemeData>()!;

    final statusLine = online == null
        ? 'Waiting for them to join…'
        : online
            ? 'Online now'
            : (partner?.lastSeen != null
                ? 'Last seen ${timeago.format(partner!.lastSeen!)}'
                : 'Offline');

    return AppCard(
      onTap: () => widget.onOpenTab(AppTab.chat),
      color: online == true
          ? ext.palette.containerFor(AppTheme.tokensOf(context))
          : null,
      child: Row(
        children: [
          Avatar(name: name, imageUrl: partner?.avatarUrl, radius: 30, online: online),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (online == true)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: AppSpacing.xs),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ext.palette.seed,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        statusLine,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chat_bubble_outline_rounded,
              size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _questionCard(BuildContext context) {
    if (_vm.loadingQuestion) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(height: 12, width: 90),
            const SizedBox(height: AppSpacing.sm),
            Skeleton(height: 20, width: MediaQuery.sizeOf(context).width * 0.55),
          ],
        ),
      );
    }

    final state = _vm.answerState;
    if (_vm.question == null || state == null) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Taking a breath today'),
            SizedBox(height: AppSpacing.xs),
            Text('The daily question will be back tomorrow.'),
          ],
        ),
      );
    }

    return AppCard(
      color: state.bothAnswered
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText.caption(context, '${state.question.emoji} ${state.question.category}'),
          const SizedBox(height: AppSpacing.sm),
          Text(state.question.text, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          _questionStateBody(context, state),
        ],
      ),
    );
  }

  Widget _questionStateBody(BuildContext context, dynamic state) {
    if (!state.bothAnswered && state.myAnswer == null) {
      return AppButton(
        label: "Answer today's question",
        expand: true,
        onPressed: _openAnswerSheet,
      );
    }
    if (!state.bothAnswered) {
      return Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Sealed — unlocks when they answer.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (_vm.canEditAnswer)
            TextButton(onPressed: _openAnswerSheet, child: const Text('Edit')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _answerBlock(context, 'You', state.myAnswer!, mine: true),
        const SizedBox(height: AppSpacing.sm),
        _answerBlock(context, _vm.partner?.displayName ?? 'Them',
            state.partnerAnswer ?? '', mine: false),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Reply in chat',
          variant: AppButtonVariant.ghost,
          onPressed: () => widget.onOpenTab(AppTab.chat),
        ),
      ],
    );
  }

  Widget _answerBlock(BuildContext context, String who, String answer, {required bool mine}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText.caption(context, who),
        const SizedBox(height: AppSpacing.xs),
        Text(answer, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Future<void> _openAnswerSheet() async {
    final existing = _vm.answerState?.myAnswer;
    final controller = TextEditingController(text: existing ?? '');
    final submitted = await showAppSheet<bool>(
      context: context,
      title: _vm.question?.text ?? 'Today',
      isScrollControlled: true,
      children: [
        AppTextField(
          label: 'Your answer',
          hint: 'Only they will ever read this…',
          controller: controller,
          maxLines: 4,
          minLines: 2,
          autofocus: true,
        ),
        const SizedBox(height: AppSpacing.md),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => AppButton(
            label: existing == null ? 'Seal my answer' : 'Update',
            expand: true,
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
    controller.dispose();
    if (submitted == true && mounted) {
      try {
        await _vm.submitAnswer(controller.text.trim());
      } catch (_) {
        if (mounted) {
          showAppToast(context, "Saved locally — we'll sync when you're online.");
        }
      }
    }
  }

  Widget _countdown(BuildContext context) {
    final plan = _vm.nextPlan!;
    final days = _vm.daysUntilNextPlan;
    final when = days <= 0
        ? 'today!'
        : days == 1
            ? 'tomorrow'
            : 'in $days days';
    return Align(
      alignment: Alignment.centerLeft,
      child: CountdownChip(
        label: '${plan.title} · $when',
        icon: Icons.event_available_rounded,
        onTap: () => widget.onOpenTab(AppTab.plans),
      ),
    );
  }

  Widget _unreadLine(BuildContext context) {
    final partnerName = _vm.partner?.displayName ?? 'them';
    return InkWell(
      onTap: () => widget.onOpenTab(AppTab.chat),
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${_vm.unreadFromPartner} new from $partnerName',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

String _weekday(int i) => const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][i - 1];
String _month(int i) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][i - 1];
