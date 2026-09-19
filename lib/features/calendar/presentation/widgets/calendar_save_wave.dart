import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/motion.dart';

/// Shows a short, non-interactive ripple across the entire app surface.
///
/// This is intentionally an [OverlayEntry] rather than a dialog: saving an
/// event has already completed, so the acknowledgement must not delay or
/// intercept the user's next action.
void showSaveWave(BuildContext context) {
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: IgnorePointer(
        child: _CalendarSaveWave(
          onComplete: () {
            entry.remove();
            entry.dispose();
          },
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

class _CalendarSaveWave extends StatefulWidget {
  const _CalendarSaveWave({required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_CalendarSaveWave> createState() => _CalendarSaveWaveState();
}

class _CalendarSaveWaveState extends State<_CalendarSaveWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    _isInitialized = true;
    // AppMotion reads MediaQuery for the system reduce-motion preference, so
    // it must run after inherited widgets are available.
    _controller =
        AnimationController(
          vsync: this,
          duration: AppMotion.of(context, AppMotion.calendarSaveWave),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onComplete();
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = MediaQuery.of(context).disableAnimations;
    final theme = Theme.of(context);
    // Preserve the selected palette's hue, with vivid contrast in either mode.
    final color = HSLColor.fromColor(theme.colorScheme.primary)
        .withSaturation(0.80)
        .withLightness(theme.brightness == Brightness.dark ? 0.68 : 0.42)
        .toColor();
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _CalendarSaveWavePainter(
          animation: _controller,
          color: color,
          reduceMotion: disabled,
        ),
      ),
    );
  }
}

class _CalendarSaveWavePainter extends CustomPainter {
  _CalendarSaveWavePainter({
    required this.animation,
    required this.color,
    required this.reduceMotion,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color color;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final centre = size.center(Offset.zero);
    final maxRadius =
        math.sqrt(centre.dx * centre.dx + centre.dy * centre.dy) + 16;
    if (reduceMotion) {
      // A stationary tint fading out remains visible inside the viewport.
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = color.withValues(alpha: 0.10 * (1 - progress)),
      );
      return;
    }

    for (var index = 0; index < 2; index++) {
      final local = (progress - index * 0.12) / 0.88;
      if (local <= 0 || local >= 1) continue;
      // Continuous ease-in/out opacity prevents rings appearing or disappearing
      // abruptly. Repaint directly from the controller without rebuilding UI.
      final fade = math.sin(math.pi * local);
      final radius = maxRadius * Curves.easeOutSine.transform(local);
      for (final width in [42.0, 28.0, 14.0]) {
        canvas.drawCircle(
          centre,
          radius,
          Paint()
            ..color = color.withValues(alpha: 0.045 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = width,
        );
      }
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.12 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7,
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.50 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_CalendarSaveWavePainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.color != color ||
      oldDelegate.reduceMotion != reduceMotion;
}
