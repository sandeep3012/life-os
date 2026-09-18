import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The design's circular progress ring: a full-circle track with a round-capped
/// arc drawn over it, starting at 12 o'clock and sweeping clockwise.
///
/// The comp draws these as SVG circles with `stroke-dasharray`/`stroke-dashoffset`
/// on an element rotated −90°; `CustomPainter` reproduces the same geometry
/// directly. Used at 48px/5px stroke for the dashboard habit tiles and at
/// 132px/15px stroke for the finance donut's single-value variant.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.color,
    this.trackColor,
    this.child,
  });

  /// 0..1. Values outside that range are clamped, so a habit logged beyond its
  /// target doesn't wrap the arc back past 12 o'clock.
  final double progress;

  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;

  /// Centred content — the comp shows a percentage or a tick.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          strokeWidth: strokeWidth,
          color: color,
          trackColor: trackColor ?? scheme.outline,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 12 o'clock, matching the comp's rotate(-90deg)
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) {
    return old.progress != progress ||
        old.strokeWidth != strokeWidth ||
        old.color != color ||
        old.trackColor != trackColor;
  }
}
