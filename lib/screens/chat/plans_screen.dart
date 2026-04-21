import 'dart:async';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../widgets/responsive_wrapper.dart';

/// Card-based date planner for the #plans channel.
class PlansScreen extends StatefulWidget {
  final Channel channel;
  final AuthService authService;
  final ChatService chatService;
  final PresenceService presenceService;

  const PlansScreen({super.key, required this.channel, required this.authService, required this.chatService, required this.presenceService});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.chatService.loadMessages(widget.channel.id);
    widget.chatService.subscribeToMessages(widget.channel.id);
  }

  @override
  void dispose() {
    widget.chatService.unsubscribeFromMessages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cc = AppTheme.colorsFor(ChannelType.plans);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.channelBgGradient(ChannelType.plans)),
        child: SafeArea(
          child: ResponsiveWrapper(maxWidth: 520, child: Column(children: [
            _appBar(cc),
            Expanded(child: _body(cc)),
          ])),
        ),
      ),
      floatingActionButton: _fab(cc),
    );
  }

  Widget _appBar(ChannelColors c) => ClipRRect(child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
    child: Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      decoration: BoxDecoration(color: AppTheme.surface.withValues(alpha: 0.85), border: Border(bottom: BorderSide(color: c.accent.withValues(alpha: 0.08)))),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_rounded, size: 22), color: AppTheme.onSurface, onPressed: () => Navigator.pop(context)),
        Container(width: 38, height: 38, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart.withValues(alpha: 0.2), c.gradientEnd.withValues(alpha: 0.1)]), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('📅', style: TextStyle(fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('#plans', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          Text('Your dates & adventures', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.accent, fontSize: 12)),
        ])),
      ]),
    ),
  ));

  Widget _body(ChannelColors c) => ListenableBuilder(
    listenable: widget.chatService,
    builder: (context, _) {
      final plans = widget.chatService.plansForChannel(widget.channel.id);
      final upcoming = plans.where((p) => !p.isCompleted).toList()..sort((a, b) {
        if (a.plannedDate == null && b.plannedDate == null) return 0;
        if (a.plannedDate == null) return 1;
        if (b.plannedDate == null) return -1;
        return a.plannedDate!.compareTo(b.plannedDate!);
      });
      final completed = plans.where((p) => p.isCompleted).toList();

      if (plans.isEmpty) return _emptyState(c);

      return ListView(padding: const EdgeInsets.all(16), children: [
        // Countdown to next plan
        if (upcoming.isNotEmpty && upcoming.first.plannedDate != null)
          _countdownCard(upcoming.first, c).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader('Upcoming', '${upcoming.length}', c),
          const SizedBox(height: 8),
          ...upcoming.asMap().entries.map((e) => _planCard(e.value, c, e.key)),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader('Completed', '${completed.length}', c),
          const SizedBox(height: 8),
          ...completed.asMap().entries.map((e) => _planCard(e.value, c, e.key, done: true)),
        ],
        const SizedBox(height: 80),
      ]);
    },
  );

  Widget _countdownCard(Plan plan, ChannelColors c) {
    final now = DateTime.now();
    final days = plan.plannedDate!.difference(now).inDays;
    final isPast = days < 0;
    final label = isPast ? '${-days} day${-days == 1 ? '' : 's'} ago' : days == 0 ? 'Today! 🎉' : '$days day${days == 1 ? '' : 's'} to go';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.gradientStart.withValues(alpha: 0.15), c.gradientEnd.withValues(alpha: 0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(isPast ? '📍' : days == 0 ? '🎉' : '⏳', style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isPast ? 'Last plan' : 'Next up', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
            Text(plan.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: c.accent),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: c.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(width: 8),
            Text('• ${DateFormat.MMMd().format(plan.plannedDate!)}', style: TextStyle(color: c.accent.withValues(alpha: 0.7), fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, String count, ChannelColors c) => Row(children: [
    Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5), letterSpacing: 1.5, fontWeight: FontWeight.w600)),
    const SizedBox(width: 8),
    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(count, style: TextStyle(color: c.accent, fontSize: 11, fontWeight: FontWeight.w600))),
  ]);

  Widget _planCard(Plan plan, ChannelColors c, int index, {bool done = false}) {
    final isMine = plan.createdBy == widget.authService.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainer.withValues(alpha: done ? 0.4 : 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? AppTheme.outline.withValues(alpha: 0.08) : c.accent.withValues(alpha: 0.1)),
        ),
        child: Material(color: Colors.transparent, child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _togglePlan(plan),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            // Checkbox
            Container(width: 28, height: 28, decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? c.accent.withValues(alpha: 0.15) : Colors.transparent,
              border: Border.all(color: done ? c.accent : AppTheme.outline.withValues(alpha: 0.3), width: 2),
            ), child: done ? Icon(Icons.check_rounded, size: 16, color: c.accent) : null),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(plan.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? AppTheme.onSurfaceVariant.withValues(alpha: 0.5) : AppTheme.onSurface,
              )),
              const SizedBox(height: 2),
              Row(children: [
                if (plan.plannedDate != null) ...[
                  Icon(Icons.event_rounded, size: 12, color: c.accent.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(DateFormat.MMMd().format(plan.plannedDate!), style: TextStyle(fontSize: 11, color: c.accent.withValues(alpha: 0.7))),
                  const SizedBox(width: 8),
                ],
                if (plan.location != null && plan.location!.isNotEmpty) ...[
                  Icon(Icons.place_rounded, size: 12, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(width: 2),
                  Flexible(child: Text(plan.location!, style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ])),
            // Who suggested
            Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent.withValues(alpha: 0.1)),
              child: Center(child: Text(isMine ? 'Y' : (widget.authService.partnerProfile?.displayName ?? 'P')[0], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accent)))),
          ])),
        )),
      ),
    ).animate(delay: Duration(milliseconds: 50 * index)).fadeIn(duration: 300.ms).slideX(begin: 0.03, end: 0);
  }

  void _togglePlan(Plan plan) {
    HapticFeedback.lightImpact();
    widget.chatService.togglePlanCompleted(plan.id, widget.channel.id, !plan.isCompleted);
  }

  Widget _emptyState(ChannelColors c) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.accent.withValues(alpha: 0.1), c.gradientEnd.withValues(alpha: 0.05)]), shape: BoxShape.circle),
      child: const Center(child: Text('📅', style: TextStyle(fontSize: 36)))).animate(onPlay: (ctrl) => ctrl.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 2500.ms),
    const SizedBox(height: 20),
    Text('Plan something special', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
    const SizedBox(height: 6),
    Text('Tap + to add your first date idea 💡', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5))),
  ])).animate().fadeIn(duration: 600.ms);

  Widget _fab(ChannelColors c) => Container(
    decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart, c.gradientEnd]), borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))]),
    child: FloatingActionButton(
      onPressed: () => _showAddPlan(c),
      backgroundColor: Colors.transparent, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
    ),
  );

  void _showAddPlan(ChannelColors c) {
    final titleCtrl = TextEditingController();

    final locationCtrl = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: BoxDecoration(color: AppTheme.surfaceContainer, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: c.accent.withValues(alpha: 0.1)))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.outline, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Text('✨', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text('New Plan', style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text('Add a date idea or plan something special', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          // Title
          TextField(controller: titleCtrl, decoration: InputDecoration(hintText: 'What\'s the plan?', prefixIcon: Icon(Icons.lightbulb_outline_rounded, size: 20, color: c.accent),
            filled: true, fillColor: AppTheme.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent.withValues(alpha: 0.5), width: 1.5))),
            textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 12),
          // Location (optional)
          TextField(controller: locationCtrl, decoration: InputDecoration(hintText: 'Location (optional)', prefixIcon: Icon(Icons.place_outlined, size: 20, color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
            filled: true, fillColor: AppTheme.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.outlineVariant)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent.withValues(alpha: 0.5), width: 1.5)))),
          const SizedBox(height: 12),
          // Date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (picked != null) setSheet(() => selectedDate = picked);
            },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: AppTheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.outlineVariant)),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 20, color: selectedDate != null ? c.accent : AppTheme.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(width: 12),
                Text(selectedDate != null ? DateFormat.yMMMd().format(selectedDate!) : 'Pick a date (optional)',
                  style: TextStyle(color: selectedDate != null ? AppTheme.onSurface : AppTheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 15)),
              ])),
          ),
          const SizedBox(height: 20),
          Container(height: 52, decoration: BoxDecoration(gradient: LinearGradient(colors: [c.gradientStart, c.gradientEnd]), borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))]),
            child: ElevatedButton(onPressed: () {
              if (titleCtrl.text.trim().isNotEmpty) {
                widget.chatService.createPlan(channelId: widget.channel.id, senderId: widget.authService.currentUser!.id,
                  title: titleCtrl.text.trim(), location: locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null, plannedDate: selectedDate);
                Navigator.pop(ctx);
              }
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text('Add Plan ✨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)))),
        ]),
      )),
    );
  }
}
