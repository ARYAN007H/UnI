import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The one avatar component with the presence dot. Initials are the
/// fallback; the online dot uses the couple seed (vivid moment, plan §4).
class Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final bool? online;

  const Avatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 28,
    this.online,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<UAndiThemeData>()!.palette;

    Widget content;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      content = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initials(context, palette),
          placeholder: (_, __) => Container(
            width: radius * 2,
            height: radius * 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.14),
          ),
        ),
      );
    } else {
      content = _initials(context, palette);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        if (online != null)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.42,
              height: radius * 0.42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online!
                    ? palette.seed
                    : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _initials(BuildContext context, CouplePalette palette) {
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: palette.containerFor(
          AppTheme.tokensOf(context))),
      child: Text(
        letter,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }
}
