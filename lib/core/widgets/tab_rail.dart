import 'package:flutter/material.dart';

import '../../app/motion.dart';
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
class AppTabRail<T> extends StatefulWidget {
  const AppTabRail({
    super.key,
    required this.value,
    required this.labels,
    this.icons = const {},
    required this.onChanged,
    this.onChangedAt,
    this.height = 38,
    this.fontSize = 13,
  });

  final T value;

  /// Ordered: the map's iteration order is the display order.
  final Map<T, String> labels;

  /// Optional glyphs let compact tabs retain their meaning at a glance.
  final Map<T, IconData> icons;

  final ValueChanged<T> onChanged;

  /// Called instead of [onChanged] when set, with the tapped segment's centre
  /// in global coordinates — for a transition that starts where the tap was.
  final void Function(T value, Offset? origin)? onChangedAt;

  final double height;
  final double fontSize;

  @override
  State<AppTabRail<T>> createState() => _AppTabRailState<T>();

  /// [shown] is the tab the pill and inks are drawn at; [value] is what is
  /// actually selected, for semantics.
  Widget _build(BuildContext context, T shown) {
    final scheme = Theme.of(context).colorScheme;
    final entries = labels.entries.toList();
    final index = entries.indexWhere((e) => e.key == shown);
    final count = entries.length;
    final slide = AppMotion.of(context, AppMotion.tabSlide);
    final slideCurve = AppMotion.curveOf(context, AppMotion.tabSlideCurve);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // One pill behind the segments that slides to the chosen one,
          // rather than each segment painting its own.
          if (index >= 0)
            Positioned.fill(
              child: AnimatedAlign(
                alignment: Alignment(
                  count == 1 ? 0 : -1 + 2 * index / (count - 1),
                  0,
                ),
                duration: slide,
                curve: slideCurve,
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(10),
                      // Kit: the selected pill lifts off the track.
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final entry in entries)
                Expanded(
                  child: Builder(
                    builder: (segmentContext) => Tappable(
                      onTap: () {
                        final at = onChangedAt;
                        if (at == null) {
                          onChanged(entry.key);
                        } else {
                          at(entry.key, _centreOf(segmentContext));
                        }
                      },
                      haptic: TapHaptic.selection,
                      semanticLabel: entry.value,
                      selected: entry.key == value,
                      // The pill is [height] (38 per the kit) but the tappable
                      // area around it is 44, which is the kit's floor.
                      // Shrink-wrapping via `enforceMinTouchTarget` would
                      // collapse these equal-width Expanded segments, so the
                      // height is added here instead.
                      child: Container(
                        height: AppSpacing.minTouchTarget,
                        alignment: Alignment.center,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: entry.key == shown ? 1 : 0),
                          duration: AppMotion.of(context, AppMotion.navColor),
                          builder: (context, selected, _) {
                            final ink = Color.lerp(
                              scheme.onSurfaceVariant,
                              scheme.onPrimary,
                              selected,
                            );
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icons[entry.key] case final icon?) ...[
                                  Icon(icon, size: fontSize + 4, color: ink),
                                  const SizedBox(width: 7),
                                ],
                                Flexible(
                                  child: Text(
                                    entry.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppFonts.sans,
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w700,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Offset? _centreOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }
}

class _AppTabRailState<T> extends State<AppTabRail<T>> {
  late T _shown = widget.value;

  @override
  void didUpdateWidget(AppTabRail<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _shown) return;
    // The pill moves a frame late, together with [TabSlide]'s content: the
    // frame that builds the new tab is slow, and a pill already moving through
    // it would finish ahead of the page it belongs to.
    final target = widget.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.value == target && _shown != target) {
        setState(() => _shown = target);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget._build(context, _shown);
}
