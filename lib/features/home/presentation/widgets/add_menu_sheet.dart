import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/motion.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/tappable.dart';

/// One tile in the add menu.
class AddMenuItem {
  const AddMenuItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

/// The FAB's add menu. Comp: a bottom sheet on `bg` with a top radius of 30, a
/// 40×4 grab handle, a serif title, then a 2-column grid of radius-19 tiles each
/// carrying a 38px icon well at 15% of the tile colour, and a full-width Cancel
/// below. Tiles stagger in 40ms apart.
///
/// Call [showAddMenuSheet] rather than building this directly.
class AddMenuSheet extends StatelessWidget {
  const AddMenuSheet({super.key, required this.items});

  final List<AddMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.appColors;

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final right = i + 1 < items.length ? items[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < items.length ? 11 : 0),
          // See the habit grid: `stretch` needs a bounded height, and this
          // Column is mainAxisSize.min so the Row's is unbounded without it.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Tile(item: items[i], index: i)),
                const SizedBox(width: 11),
                Expanded(
                  child: right == null
                      ? const SizedBox()
                      : _Tile(item: right, index: i + 1),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.sheetRadius),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.text3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'What are we adding?',
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ...rows,
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item, required this.index});

  final AddMenuItem item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final tile = Tappable(
      haptic: TapHaptic.light,
      semanticLabel: '${item.label}, ${item.subtitle}',
      onTap: () {
        Navigator.of(context).pop();
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, size: 20, color: item.color),
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            Text(
              item.subtitle,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    // Comp: `stagger` — opacity 0→1 with translateY 14→0, 340ms, 40ms apart.
    return tile
        .animate()
        .fadeIn(
          duration: AppMotion.menuTile,
          delay: AppMotion.menuTileStagger * index,
        )
        .slideY(
          begin: 0.18,
          end: 0.0,
          duration: AppMotion.menuTile,
          curve: AppMotion.emphasized,
        );
  }
}

/// Presents [AddMenuSheet] with the comp's sheet chrome and motion.
Future<void> showAddMenuSheet(
  BuildContext context, {
  required List<AddMenuItem> items,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => AddMenuSheet(items: items),
  );
}
