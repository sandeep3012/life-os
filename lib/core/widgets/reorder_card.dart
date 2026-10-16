import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_fonts.dart';
import '../../app/theme/app_spacing.dart';

/// The line above a reorderable list saying how it works — dragging isn't
/// something people find on their own.
class ReorderHint extends StatelessWidget {
  const ReorderHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.gripVertical, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of a reorderable list, as a card on the page's own background.
///
/// Hold anywhere on it to pick it up, or drag the grip straight away. While
/// it's being dragged, [ReorderCard.decorateDragged] lifts it onto a raised
/// surface so it's clear what's moving.
class ReorderCard extends StatelessWidget {
  const ReorderCard({
    super.key,
    required this.index,
    required this.leading,
    required this.title,
    this.subtitle,
    this.isDefault = false,
    this.onTap,
    this.dragLabel,
  });

  final int index;
  final Widget leading;
  final String title;
  final String? subtitle;

  /// Marks the item new entries start on.
  final bool isDefault;
  final VoidCallback? onTap;

  /// The grip's tooltip and screen-reader label.
  final String? dragLabel;

  /// For `proxyDecorator`: the card being dragged, lifted and tilted.
  static Widget decorateDragged(
    Widget child,
    int index,
    Animation<double> animation,
  ) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => _Lift(
      amount: Curves.easeOut.transform(animation.value),
      child: child!,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final lift = _Lift.amountOf(context);
    final radius = BorderRadius.circular(AppSpacing.tileRadius);

    final card = Material(
      // The page's colour at rest, like the app's other lists; raised only
      // while dragged.
      color: Color.lerp(Colors.transparent, scheme.surface, lift),
      elevation: 8 * lift,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: Color.lerp(scheme.outlineVariant, scheme.primary, lift)!,
          width: 1 + 0.5 * lift,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (isDefault)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Default',
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: colors.accentInk,
                    ),
                  ),
                ),
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: dragLabel ?? 'Drag to reorder $title',
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      LucideIcons.gripVertical,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Hold anywhere on the card to pick it up.
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: Transform.rotate(
          angle: -0.015 * lift,
          child: Transform.scale(scale: 1 + 0.02 * lift, child: card),
        ),
      ),
    );
  }
}

/// How far the card under it is lifted, 0–1 — set only around the copy the
/// list is dragging, so the card can raise its own surface (and not the
/// spacing around it).
class _Lift extends InheritedWidget {
  const _Lift({required this.amount, required super.child});

  final double amount;

  static double amountOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Lift>()?.amount ?? 0;

  @override
  bool updateShouldNotify(_Lift old) => old.amount != amount;
}
