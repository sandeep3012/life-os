import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/goal_progress.dart';
import 'goal_ring.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String formatGoalValue(String type, double value) {
  if (type == 'financial') return _currencyFormat.format(value);
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.data, required this.onTap});

  final GoalWithLinks data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final goal = data.goal;
    final color = switch (goal.type) {
      'financial' => colors.finance,
      'habit' => colors.habits,
      _ => colors.goals,
    };

    final target = goal.targetValue;
    final progressLabel = target == null
        ? formatGoalValue(goal.type, goal.currentValue)
        : '${formatGoalValue(goal.type, goal.currentValue)} / ${formatGoalValue(goal.type, target)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GoalRing(ratio: data.ratio, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progressLabel,
                      style: TextStyle(
                        fontFamily: 'PlexMono',
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (data.links.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final link in data.links)
                            Chip(
                              label: Text(link.label, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
