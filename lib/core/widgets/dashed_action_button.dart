import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_fonts.dart';
import 'tappable.dart';

/// The comp's full-width "add" affordance: a 52px row at radius 18 with a 1.5px
/// dashed outline — used for "Build a new habit" and "Write a new note".
///
/// Flutter has no dashed [Border], so the outline is painted. A solid border
/// would read as a second primary button rather than an invitation to add.
class DashedActionButton extends StatelessWidget {
  const DashedActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = LucideIcons.plus,
    this.height = 52,
    this.radius = 18,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: label,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: scheme.outline, radius: radius),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;

    // Walk the rounded-rect path, stroking 6px runs separated by 5px gaps.
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + 6;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0.0, metric.length)),
          paint,
        );
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
