import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Inline voice message player with waveform visualization.
/// Designed to be embedded inside a message bubble.
class VoicePlayer extends StatefulWidget {
  final String audioUrl;
  final Duration? duration;
  final bool isMine;
  final bool isVanillaMode;

  const VoicePlayer({
    super.key,
    required this.audioUrl,
    this.duration,
    this.isMine = false,
    this.isVanillaMode = false,
  });

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _currentPosition = Duration.zero;
  late AnimationController _playAnimController;

  // Simulated waveform data (in production, extract from audio file)
  late List<double> _waveformData;

  @override
  void initState() {
    super.initState();
    _playAnimController = AnimationController(
      vsync: this,
      duration: widget.duration ?? const Duration(seconds: 10),
    );
    _playAnimController.addListener(() {
      setState(() {
        _progress = _playAnimController.value;
        if (widget.duration != null) {
          _currentPosition = widget.duration! * _progress;
        }
      });
    });
    _playAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _currentPosition = Duration.zero;
        });
        _playAnimController.reset();
      }
    });

    // Generate pseudo-random waveform data
    final random = Random(widget.audioUrl.hashCode);
    _waveformData = List.generate(
      40,
      (_) => 0.2 + random.nextDouble() * 0.8,
    );
  }

  @override
  void dispose() {
    _playAnimController.dispose();
    // TODO: Dispose actual audio player
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      // TODO: Start actual audio playback with just_audio
      // final player = AudioPlayer();
      // await player.setUrl(widget.audioUrl);
      // player.play();
      _playAnimController.forward(from: _progress);
    } else {
      // TODO: Pause actual audio playback
      _playAnimController.stop();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isMine ? AppTheme.primaryLight : AppTheme.secondary;
    final displayDuration = _isPlaying || _progress > 0
        ? _currentPosition
        : (widget.duration ?? Duration.zero);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.15),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(_isPlaying),
                  color: accent,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform
          Expanded(
            child: SizedBox(
              height: 32,
              child: CustomPaint(
                painter: _VoiceWaveformPainter(
                  waveformData: _waveformData,
                  progress: _progress,
                  playedColor: accent,
                  unplayedColor: (widget.isMine
                          ? AppTheme.onSurface
                          : AppTheme.onSurfaceVariant)
                      .withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Duration
          Text(
            _formatDuration(displayDuration),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a waveform with progress indicator.
class _VoiceWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  _VoiceWaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final barWidth = 3.0;
    final gap = (size.width - waveformData.length * barWidth) /
        (waveformData.length - 1).clamp(1, double.infinity);
    final progressX = size.width * progress;

    final playedPaint = Paint()
      ..color = playedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;
      final barHeight = waveformData[i] * size.height * 0.85;
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      canvas.drawLine(
        Offset(x, y1),
        Offset(x, y2),
        x <= progressX ? playedPaint : unplayedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
