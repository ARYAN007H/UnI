import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../models/models.dart';
import '../shell/home_shell.dart';

/// Plans — "When do we meet next?" (docs/design/plans.md). The countdown
/// hero is the loudest element; past plans stay collapsed.
class PlansScreen extends StatefulWidget {
  final ServiceBundle services;

  const PlansScreen({super.key, required this.services});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<Plan> _plans = [];
  bool _loading = true;

  String? get _plansChannelId {
    for (final c in widget.services.chatService.channels) {
      if (c.type == ChannelType.plans) return c.id;
    }
    final ch = widget.services.chatService.channels;
    return ch.isEmpty ? null : ch.first.id;
  }

  List<Plan> get _upcoming {
    final now = DateTime.now();
    return _plans
        .where((p) => !p.isCompleted && p.plannedDate != null && p.plannedDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.plannedDate!.compareTo(b.plannedDate!));
  }

  List<Plan> get _past {
    final now = DateTime.now();
    return _plans
        .where((p) => p.isCompleted ||
            p.plannedDate == null ||
            p.plannedDate!.isBefore(now))
        .toList()
      ..sort((a, b) => (b.plannedDate ?? b.createdAt).compareTo(a.plannedDate ?? a.createdAt));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Ensure message history for the plans channel is in memory.
    final id = _plansChannelId;
    if (id != null) {
      await widget.services.chatService.loadMessages(id);
    }
    if (!mounted) return;
    _refreshFromService();
    setState(() => _loading = false);
  }

  void _refreshFromService() {
    final id = _plansChannelId;
    _plans = id == null ? [] : widget.services.chatService.plansForChannel(id);
  }

  Future<void> _createSheet() async {
    final created = await showAppSheet<bool>(
      context: context,
      title: 'Plan the next hug',
      isScrollControlled: true,
      children: [_CreatePlanForm(services: widget.services)],
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Plans'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan'),
      ),
      body: ListenableBuilder(
        listenable: widget.services.chatService,
        builder: (context, _) {
          _refreshFromService();
          final upcoming = _upcoming;
          final past = _past;

          if (_loading) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                Skeleton(height: 140),
                SizedBox(height: AppSpacing.md),
                Skeleton(height: 80),
                SizedBox(height: AppSpacing.sm),
                Skeleton(height: 80),
              ],
            );
          }

          if (_plans.isEmpty) {
            return EmptyState(
              title: 'Nothing planned yet.',
              subtitle: 'Distance counts down better with a date on the calendar.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
            children: [
              if (upcoming.isNotEmpty) ...[
                _hero(context, upcoming.first),
                const SizedBox(height: AppSpacing.lg),
                for (final p in upcoming.skip(1)) ...[
                  _planCard(context, p),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
              if (past.isNotEmpty) ...[
                SectionHeader(title: 'Past · ${past.length}'),
                for (final p in past)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _planCard(context, p, muted: true),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context, Plan plan) {
    final days = _daysUntil(plan);
    final when = days <= 0 ? 'today' : days == 1 ? 'tomorrow' : '$days';
    final ext = Theme.of(context).extension<UAndiThemeData>()!;
    return AppCard(
      color: ext.palette.containerFor(AppTheme.tokensOf(context)),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            days <= 1 ? when : when,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          Text(days <= 1 ? '' : 'days',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.md),
          Text(plan.title, style: Theme.of(context).textTheme.headlineMedium),
          if (plan.location != null && plan.location!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text(plan.location!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
          if (plan.plannedDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              DateFormat('EEE, d MMMM · h:mm a').format(plan.plannedDate!),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, Plan plan, {bool muted = false}) {
    final theme = Theme.of(context);
    return AppCard(
      color: muted ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        plan.title,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (plan.isCompleted) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ],
                ),
                if (plan.location != null && plan.location!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    plan.location!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (plan.plannedDate != null)
            Text(
              DateFormat('d MMM').format(plan.plannedDate!),
              style: theme.textTheme.labelMedium,
            ),
        ],
      ),
    );
  }

  int _daysUntil(Plan plan) {
    if (plan.plannedDate == null) return 0;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final target = plan.plannedDate!;
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.difference(startOfDay).inDays;
  }
}

class _CreatePlanForm extends StatefulWidget {
  final ServiceBundle services;
  const _CreatePlanForm({required this.services});

  @override
  State<_CreatePlanForm> createState() => _CreatePlanFormState();
}

class _CreatePlanFormState extends State<_CreatePlanForm> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
      );
      if (mounted) {
        setState(() => _date = DateTime(
            picked.year, picked.month, picked.day, time?.hour ?? 18, time?.minute ?? 0));
      }
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _saving) return;
    final chat = widget.services.chatService;
    final me = widget.services.authService.currentUser;
    String? plansChannelId;
    for (final c in chat.channels) {
      if (c.type == ChannelType.plans) plansChannelId = c.id;
    }
    if (me == null || plansChannelId == null) {
      showAppToast(context, "Plans aren't ready yet — reopen this screen.");
      return;
    }
    setState(() => _saving = true);
    try {
      await chat.createPlan(
        channelId: plansChannelId,
        senderId: me.id,
        title: _titleController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        plannedDate: _date,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showAppToast(context, "Couldn't save the plan — try again.");
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'What are you planning?',
          controller: _titleController,
          onChanged: (_) => setState(() {}),
          autofocus: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Where? (optional)',
          controller: _locationController,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: _date == null
              ? 'Pick a date & time'
              : DateFormat('EEE, d MMMM · h:mm a').format(_date!),
          variant: AppButtonVariant.secondary,
          icon: Icons.event_outlined,
          expand: true,
          onPressed: _pickDate,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Add plan',
          expand: true,
          loading: _saving,
          onPressed: _titleController.text.trim().isNotEmpty ? _save : null,
        ),
      ],
    );
  }
}
