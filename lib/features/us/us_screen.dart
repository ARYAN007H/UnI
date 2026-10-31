import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../shell/home_shell.dart';
import 'media_viewer.dart';
import 'us_viewmodel.dart';

/// Us — "What have we been?" (docs/design/us.md): quiet stats, month-grouped
/// photo timeline with BlurHash placeholders, voice moments. Photos are the
/// heroes; chrome recedes.
class UsScreen extends StatefulWidget {
  final ServiceBundle services;

  const UsScreen({super.key, required this.services});

  @override
  State<UsScreen> createState() => _UsScreenState();
}

class _UsScreenState extends State<UsScreen> {
  late final UsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = UsViewModel(
      authService: widget.services.authService,
      chatService: widget.services.chatService,
      mediaService: widget.services.mediaService,
    );
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(title: 'Us'),
      body: ListenableBuilder(
        listenable: Listenable.merge([_vm, widget.services.chatService]),
        builder: (context, _) {
          final groups = _vm.monthGroups;
          final voices = _vm.voiceMoments;
          if (groups.isEmpty && voices.isEmpty) {
            return EmptyState(
              title: 'No memories yet.',
              subtitle: 'Every photo and voice note you share collects here, month by month.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              _stats(context),
              ...groups.map((g) => _monthSection(context, g)),
              if (voices.isNotEmpty) ..._voiceSection(context, voices),
              _globePlaceholder(context),
            ],
          );
        },
      ),
    );
  }

  Widget _stats(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: AppCard(
        child: Row(
          children: [
            Expanded(child: _stat(context, '${_vm.daysTogether}', 'days together')),
            Container(width: 1, height: 36, color: Theme.of(context).colorScheme.outlineVariant),
            Expanded(child: _stat(context, '${_vm.photoCount}', 'photos')),
            Container(width: 1, height: 36, color: Theme.of(context).colorScheme.outlineVariant),
            Expanded(child: _stat(context, '${_vm.voiceCount}', 'voice notes')),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontFeatures: const [])),
        const SizedBox(height: AppSpacing.xs),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _monthSection(BuildContext context, MonthGroup group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: group.title, padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: group.messages.length,
            itemBuilder: (context, i) {
              final m = group.messages[i];
              return InkWell(
                onTap: () => _openViewer(context, group, i),
                child: BlurHashedImage(
                  thumbnailUrl: m.mediaThumbnailUrl,
                  loadImage: () async {
                    final path = await _vm.resolve(m.mediaUrl);
                    return fileImageFromPath(path);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openViewer(BuildContext context, MonthGroup group, int index) {
    Navigator.of(context).push(AppRouter.fadeThrough(
      MediaViewer(items: group.messages, initialIndex: index, mediaService: widget.services.mediaService),
    ));
  }

  List<Widget> _voiceSection(BuildContext context, List<dynamic> voices) {
    return [
      SectionHeader(title: 'Voice moments'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: [
            for (final v in voices)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Row(
                    children: [
                      Icon(Icons.graphic_eq_rounded,
                          size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Voice note · ${((v.mediaDurationMs ?? 0) / 1000).round()}s',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        '${v.createdAt.day}/${v.createdAt.month}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _globePlaceholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.public_rounded,
                size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'A map of everywhere you\u2019ve been — coming soon.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
