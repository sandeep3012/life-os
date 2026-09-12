import 'package:flutter/material.dart';

import '../../app/theme/app_fonts.dart';
import '../../app/theme/app_spacing.dart';
import 'tappable.dart';

/// The design's segmented control: a `surface-2` track at radius 14 with 5px of
/// padding, holding pills that turn `surface` when active.
///
/// Material's [SegmentedButton] can't render the track itself — only the
/// segments — so with this design's borderless, transparent segments it
/// disappears into the page. That's why this exists rather than theming
/// `SegmentedButton`.
class AppTabRail<T> extends StatelessWidget {
  const AppTabRail({
    super.key,
    required this.value,
    required this.labels,
    required this.onChanged,
    this.height = 38,
    this.fontSize = 13,
  });

  final T value;

  /// Ordered: the map's iteration order is the display order.
  final Map<T, String> labels;

  final ValueChanged<T> onChanged;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final entry in labels.entries)
            Expanded(
              child: Tappable(
                onTap: () => onChanged(entry.key),
                haptic: TapHaptic.selection,
                semanticLabel: entry.value,
                selected: entry.key == value,
                // The pill is [height] (38 per the kit) but the tappable area
                // around it is 44, which is the kit's floor. Shrink-wrapping via
                // `enforceMinTouchTarget` would collapse these equal-width
                // Expanded segments, so the height is added here instead.
                child: Container(
                  height: AppSpacing.minTouchTarget,
                  alignment: Alignment.center,
                  child: Container(
                    height: height,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.key == value
                          ? scheme.surface
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      // Kit: the selected pill lifts off the track.
                      boxShadow: entry.key == value
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        color: entry.key == value
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
