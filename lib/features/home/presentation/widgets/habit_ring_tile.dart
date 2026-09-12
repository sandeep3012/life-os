import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';

/// A habit tile from the dashboard's 2-column grid. Comp: radius 18, padding 14,
/// a 48px ring (r=20, 5px stroke, round cap) showing a percentage or a tick, then
/// the habit name at 14px w700 over an 11.5px caption.
///
/// The comp's ring tracks a per-day counter ("6 / 8 glasses") and its tap
/// increments that counter. This app models habits as done/not-done per day
/// against a weekly target, so the ring shows real week completion and the tap
/// toggles today — the same interaction shape against the data that actually
/// exists, rather than a counter the schema can't store.
class HabitRingTile extends StatelessWidget {
  const HabitRingTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.progress,
    required this.onTap,
    this.complete = false,
  });

  final String name;
  final String subtitle;

  /// 0..1 — completion against the habit's weekly target.
  final double progress;

  final VoidCallback onTap;

  /// Shows a tick instead of a percentage.
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: '$name, $subtitle',
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Row(
          children: [
            ProgressRing(
              progress: progress,
              size: 48,
              strokeWidth: 5,
              color: scheme.secondary,
              child: complete
                  ? Icon(LucideIcons.check, size: 18, color: scheme.onSurface)
                  : Text(
                      '${(progress.clamp(0.0, 1.0) * 100).round()}%',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
