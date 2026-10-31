import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import '../../core/widgets/widgets.dart';
import '../../models/models.dart';
import '../../services/media_service.dart';

/// Full-bleed media viewer (us.md): paper background, swipe between items,
/// pinch zoom via InteractiveViewer, close chrome minimal.
class MediaViewer extends StatefulWidget {
  final List<Message> items;
  final int initialIndex;
  final MediaService mediaService;
  final VoidCallback? onDelete;

  const MediaViewer({
    super.key,
    required this.items,
    required this.mediaService,
    this.initialIndex = 0,
    this.onDelete,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.tokensOf(context);
    return Scaffold(
      backgroundColor: t.base,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: t.onSurface,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: widget.onDelete,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final m = widget.items[i];
          return Column(
            children: [
              Expanded(
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: BlurHashedImage(
                        thumbnailUrl: m.mediaThumbnailUrl,
                        loadImage: () async {
                          final path =
                              await widget.mediaService.downloadMedia(m.mediaUrl ?? '');
                          return fileImageFromPath(path);
                        },
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _dateLine(m.createdAt),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _dateLine(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
