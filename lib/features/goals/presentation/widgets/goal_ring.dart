import 'package:flutter/material.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../core/widgets/progress_ring.dart';

/// A goal's completion ring with the percentage centred inside.
///
/// Draws with the kit's [ProgressRing] rather than stacking two
/// [CircularProgressIndicator]s: Material centres its stroke on the box edge,
/// so inside a same-sized [Stack] (which clips) half the stroke was cut off
/// all the way round and the ring never read as complete.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.ratio,
    required this.color,
    this.size = 64,
    this.strokeWidth = 7,
  });

  final double ratio;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ProgressRing(
      progress: ratio,
      size: size,
      strokeWidth: strokeWidth,
      color: color,
      trackColor: scheme.onSurface.withValues(alpha: 0.18),
      child: Text(
        '${(ratio * 100).round()}%',
        style: const TextStyle(
          fontFamily: AppFonts.numeric,
          fontFeatures: AppFonts.tabular,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
