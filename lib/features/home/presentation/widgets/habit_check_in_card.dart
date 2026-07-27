import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../habits/domain/habit_progress.dart';

class HabitCheckInCard extends StatelessWidget {
  const HabitCheckInCard({super.key, required this.progress, required this.onToggle});

  final HabitProgress progress;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final atRisk = progress.isAtRisk;
    final accent = atRisk ? colors.critical : colors.habits;
    final doneToday = progress.weekCompletion[DateTime.now().weekday] ?? false;

    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    doneToday
                        ? Icons.check_rounded
                        : Icons.local_fire_department_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  progress.habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  atRisk
                      ? 'at risk · ${progress.streakDays}d'
                      : '${progress.streakDays} day${progress.streakDays == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
