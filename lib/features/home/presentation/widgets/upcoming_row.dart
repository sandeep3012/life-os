import 'package:flutter/material.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';

/// A "Coming up" row. Comp: radius 16, a 40px radius-12 icon well filled with the
/// row's colour at 15% alpha, the glyph in that colour at full opacity, then
/// title 14px w700 over a 12px caption, and a bold relative time on the trailing
/// edge in the same colour.
///
/// The 15%-alpha-well / full-opacity-glyph pairing is the design's standard
/// treatment for anything category-coloured, so it also drives the finance
/// transaction avatars and the add-menu tiles.
class UpcomingRow extends StatelessWidget {
  const UpcomingRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// Comp: `in 1h` / `in 3d` — 12px w800 in [color].
  final String trailing;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final row = SurfaceCard.row(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Tappable(
      onTap: onTap,
      haptic: TapHaptic.light,
      semanticLabel: '$title, $subtitle, $trailing',
      child: row,
    );
  }
}
