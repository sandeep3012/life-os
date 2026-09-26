import 'package:flutter/material.dart';

import '../../app/motion.dart';
import 'tappable.dart';

/// A compact, toggleable filter chip for a horizontal filter row — Documents'
/// type filter and the Goals filters share it so the two read identically.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Tint when selected. Null uses the theme's primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Tappable(
      haptic: TapHaptic.selection,
      semanticLabel: label,
      selected: selected,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.of(context, const Duration(milliseconds: 150)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? effectiveColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: effectiveColor.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected
                    ? effectiveColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? effectiveColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
