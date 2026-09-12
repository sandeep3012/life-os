import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// The design's standard content card: a `--surface` fill with a 1px `--border`
/// hairline and no shadow.
///
/// The comp is explicit that "cards use borders, not shadows" — the only shadowed
/// surfaces in the whole design are the floating nav pill and the selected
/// segmented pill. Reach for this instead of Material [Card] so that rule holds
/// by default.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppSpacing.cardRadius,
    this.color,
  });

  /// Compact row/tile variant — the comp uses radius 16 with 14/15 padding for
  /// list rows, against 22 and 20 for full content cards.
  const SurfaceCard.row({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    this.radius = AppSpacing.tileRadius,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
