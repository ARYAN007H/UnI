import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

/// A hold-to-record voice message widget.
/// Replaces the send button when the text field is empty.
class VoiceRecorder extends StatefulWidget {
  /// Called when recording is completed with the file path.
  final void Function(String filePath, Duration duration) onRecordingComplete;

  /// Called when recording is cancelled.
  final VoidCallback? onRecordingCancelled;

  /// Channel accent color for theming.
  final Color? accentColor;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingCancelled,
    this.accentColor,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isCancelling = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  double _slideOffset = 0;
  final double _cancelThreshold = -100;
  late AnimationController _pulseController;

  // Simulated amplitude for visual feedback
  final List<double> _amplitudes = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accent => widget.accentColor ?? AppTheme.primary;

  void _startRecording() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = true;
      _isCancelling = false;
      _recordingDuration = Duration.zero;
      _slideOffset = 0;
      _amplitudes.clear();
    });

    _pulseController.repeat(reverse: true);

    // Start duration timer
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordingDuration += const Duration(milliseconds: 100);
        // Simulate amplitude
        _amplitudes.add(0.3 + _random.nextDouble() * 0.7);
        if (_amplitudes.length > 40) _amplitudes.removeAt(0);
      });
    });

    // TODO: Start actual recording with the `record` package
    // final recorder = AudioRecorder();
    // if (await recorder.hasPermission()) {
    //   final dir = await getTemporaryDirectory();
    //   final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    //   await recorder.start(const RecordConfig(), path: path);
    // }
  }

  void _stopRecording() async {
    if (!_isRecording) return;

    _timer?.cancel();
    _pulseController.stop();

    if (_isCancelling) {
      // Cancel recording
      setState(() {
        _isRecording = false;
        _isCancelling = false;
      });
      HapticFeedback.lightImpact();
      widget.onRecordingCancelled?.call();
      return;
    }

    // Complete recording
    setState(() => _isRecording = false);
    HapticFeedback.mediumImpact();

    // TODO: Stop actual recording and get path
    // final recorder = AudioRecorder();
    // final path = await recorder.stop();
    // if (path != null) {
    //   widget.onRecordingComplete(path, _recordingDuration);
    // }

    // For now, pass a placeholder
    widget.onRecordingComplete('recording.m4a', _recordingDuration);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isRecording) return;
    setState(() {
      _slideOffset += details.delta.dx;
      _isCancelling = _slideOffset < _cancelThreshold;
    });

    if (_isCancelling) {
      HapticFeedback.selectionClick();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Voice recording not available on web
    if (kIsWeb) {
      return Tooltip(
        message: 'Voice messages available on mobile',
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accent.withValues(alpha: 0.1)),
          ),
          child: Icon(Icons.mic_off_rounded, color: _accent.withValues(alpha: 0.3), size: 22),
        ),
      );
    }

    if (_isRecording) {
      return _buildRecordingUI();
    }
    return _buildMicButton();
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Icon(Icons.mic_rounded, color: _accent, size: 22),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: (_) => _stopRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _isCancelling
              ? AppTheme.error.withValues(alpha: 0.1)
              : _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isCancelling
                ? AppTheme.error.withValues(alpha: 0.3)
                : _accent.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            // Recording indicator
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCancelling
                        ? AppTheme.error
                        : Colors.red.withValues(
                            alpha: 0.5 + _pulseController.value * 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(
                            alpha: 0.3 * _pulseController.value),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 10),

            // Duration
            Text(
              _formatDuration(_recordingDuration),
              style: TextStyle(
                color: _isCancelling ? AppTheme.error : AppTheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),

            // Mini waveform
            Expanded(
              child: SizedBox(
                height: 24,
                child: CustomPaint(
                  painter: _WaveformPainter(
                    amplitudes: _amplitudes,
                    color: _isCancelling ? AppTheme.error : _accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Cancel hint
            if (_isCancelling)
              Icon(Icons.delete_rounded, color: AppTheme.error, size: 20)
                  .animate()
                  .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 150.ms)
            else
              Text(
                '< Slide to cancel',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 800.ms),
          ],
        ),
      ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.95, end: 1.0, duration: 200.ms),
    );
  }
}

/// Paints a simple waveform visualization.
class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final barWidth = 3.0;
    final gap = 2.0;
    final maxBars = (size.width / (barWidth + gap)).floor();
    final bars = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    final startX = size.width - bars.length * (barWidth + gap);

    for (int i = 0; i < bars.length; i++) {
      final x = startX + i * (barWidth + gap);
      final barHeight = bars[i] * size.height * 0.8;
      final y = (size.height - barHeight) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, barHeight),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}
