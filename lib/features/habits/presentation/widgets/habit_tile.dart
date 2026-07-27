import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/habit_progress.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.progress,
    required this.onToggleToday,
  });

  final HabitProgress progress;
  final ValueChanged<bool> onToggleToday;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final atRisk = progress.isAtRisk;
    final accent = atRisk ? colors.critical : colors.habits;
    final today = DateTime.now().weekday;
    final completedToday = progress.weekCompletion[today] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_fire_department_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.habit.name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 1; i <= 7; i++) ...[
                      _WeekDot(
                        label: _weekdayLabels[i - 1],
                        on: progress.weekCompletion[i] ?? false,
                        color: colors.habits,
                      ),
                      if (i != 7) const SizedBox(width: 5),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onToggleToday(!completedToday),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded, size: 15, color: accent),
                const SizedBox(width: 3),
                Text(
                  atRisk ? 'at risk' : '${progress.streakDays}',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.label, required this.on, required this.color});

  final String label;
  final bool on;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? color : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: on ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
