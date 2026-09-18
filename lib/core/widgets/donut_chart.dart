import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One arc of a [DonutChart].
class DonutSegment {
  const DonutSegment({required this.share, required this.color});

  /// 0..1 of the whole.
  final double share;
  final Color color;
}

/// The comp's "Where it went" ring: a full-circle track with butt-capped arcs
/// laid end to end over it, starting at 12 o'clock.
///
/// Comp geometry: 132px box, r=52, `stroke-width:15`, rotated −90°, `border` as
/// the base track, and **no gap between segments** — the handoff calls this out
/// (`sectionsSpace: 0`). Drawn with a painter rather than `fl_chart` so the track
/// and the zero-gap butt caps match exactly.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 132,
    this.strokeWidth = 15,
    this.trackColor,
    this.child,
  });

  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final Color? trackColor;

  /// Centred content — the comp shows a `SPENT` overline over the total.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          segments: segments,
          strokeWidth: strokeWidth,
          trackColor: trackColor ?? scheme.outline,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.segments,
    required this.strokeWidth,
    required this.trackColor,
  });

  final List<DonutSegment> segments;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    var start = -math.pi / 2; // 12 o'clock
    for (final segment in segments) {
      if (segment.share <= 0) continue;
      final sweep = 2 * math.pi * segment.share.clamp(0.0, 1.0);
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = segment.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) {
    if (old.strokeWidth != strokeWidth || old.trackColor != trackColor) return true;
    if (old.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      if (old.segments[i].share != segments[i].share ||
          old.segments[i].color != segments[i].color) {
        return true;
      }
    }
    return false;
  }
}
