import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_fonts.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';

/// A dashboard to-do row. Comp: radius 16, padding 14/15, a 23px checkbox with
/// radius 8 and a 2px border that fills with the accent when checked, a
/// strikethrough title, and a 7px category dot on the trailing edge.
///
/// The whole row is the hit target, not just the box — the comp toggles on row
/// tap with a selection haptic.
class TodoRow extends StatelessWidget {
  const TodoRow({
    super.key,
    required this.title,
    required this.done,
    required this.onToggle,
    this.time,
    this.dotColor,
  });

  final String title;
  final bool done;
  final VoidCallback onToggle;

  /// Comp: the 12px caption under the title — a due time, or a fallback label.
  final String? time;

  /// The trailing 7px category dot. Omitted when the item has no category.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tappable(
      onTap: onToggle,
      haptic: TapHaptic.selection,
      semanticLabel: title,
      selected: done,
      child: SurfaceCard.row(
        child: Row(
          children: [
            _Checkbox(checked: done),
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
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (time != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        time!,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (dotColor != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: checked ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: checked ? scheme.primary : scheme.outline,
          width: 2,
        ),
      ),
      child: checked
          ? Icon(LucideIcons.check, size: 14, color: scheme.onPrimary)
          : null,
    );
  }
}
