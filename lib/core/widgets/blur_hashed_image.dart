import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../theme/theme.dart';

/// The one media-placeholder pattern (agent2 §7.2): the BlurHash renders
/// instantly from `media_thumbnail_url` (`blurhash:<hash>`), the real image
/// fades in once resolved. On web there is no file system — the hash stays.
class BlurHashedImage extends StatelessWidget {
  /// Raw `media_thumbnail_url` — may be `blurhash:<hash>`, a legacy URL, or null.
  final String? thumbnailUrl;

  /// Resolves the displayable image for this media (e.g.
  /// mediaService.downloadMedia(path) → File → FileImage). Return null when
  /// unavailable (web, not yet downloaded).
  final Future<ImageProvider?> Function()? loadImage;

  final BoxFit fit;
  final BorderRadius borderRadius;
  final Duration hashDuration;
  final Duration imageDuration;

  const BlurHashedImage({
    super.key,
    required this.thumbnailUrl,
    this.loadImage,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.hashDuration = const Duration(milliseconds: 150),
    this.imageDuration = const Duration(milliseconds: 200),
  });

  String? get _hash {
    final t = thumbnailUrl;
    if (t == null) return null;
    return t.startsWith('blurhash:') ? t.substring('blurhash:'.length) : null;
  }

  @override
  Widget build(BuildContext context) {
    final hash = _hash;
    final t = AppTheme.tokensOf(context);

    Widget placeholder = Container(
      color: t.containerHigh,
      alignment: Alignment.center,
    );

    Widget hashLayer = hash != null && hash.isNotEmpty
        ? BlurHash(
            hash: hash,
            imageFit: fit,
            duration: hashDuration,
            curve: AppMotion.emphasized,
          )
        : placeholder;

    if (loadImage == null) return ClipRRect(borderRadius: borderRadius, child: hashLayer);

    return ClipRRect(
      borderRadius: borderRadius,
      child: FutureBuilder<ImageProvider?>(
        future: loadImage!(),
        builder: (context, snapshot) {
          final provider = snapshot.data;
          if (provider == null) return hashLayer;
          return Stack(
            fit: StackFit.expand,
            children: [
              hashLayer,
              AnimatedOpacity(
                opacity: 1.0,
                duration: imageDuration,
                curve: AppMotion.emphasized,
                child: Image(image: provider, fit: fit),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Convenience: build an ImageProvider from a resolved local path.
/// (mediaService.downloadMedia returns a local File path; web returns null.)
ImageProvider? fileImageFromPath(String? path) =>
    (path == null || path.isEmpty) ? null : FileImage(File(path));
