import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../finance/domain/budget_progress.dart';

class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.progress, this.onEdit, this.onDelete});

  final BudgetProgress progress;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = progress.isOver ? colors.critical : colors.good;
    final fillFraction = progress.ratio.clamp(0, 1.2) / 1.2;

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                progress.category.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Text(
                    '${formatMinor(progress.spentMinor, showDecimals: false)} / ${formatMinor(progress.limitMinor, showDecimals: false)}',
                    style: TextStyle(
                      fontFamily: 'PlexMono',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  if (onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit?.call();
                        } else if (value == 'delete') {
                          onDelete?.call();
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final limitMarkX = constraints.maxWidth * (1 / 1.2);
              return SizedBox(
                height: 14,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: fillFraction.toDouble(),
                        minHeight: 10,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    Positioned(
                      left: limitMarkX - 1,
                      child: Container(
                        width: 2,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }
}
