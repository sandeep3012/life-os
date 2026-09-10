import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../domain/habit_progress.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.progress,
    required this.onToggleToday,
    required this.onTap,
  });

  final HabitProgress progress;
  final ValueChanged<bool> onToggleToday;

  /// Only the trailing arrow navigates to the habit's detail screen.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final atRisk = progress.isAtRisk;
    final accent = atRisk ? colors.critical : colors.habits;
    final today = DateTime.now().weekday;
    final completedToday = progress.weekCompletion[today] ?? false;
    final category = progress.category;
    final categoryColor = category == null
        ? null
        : Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));
    final iconColor = categoryColor ?? accent;
    final iconValue = category?.icon;

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: iconValue == null
                  ? Icon(Icons.local_fire_department_rounded, color: iconColor, size: 20)
                  : IconOrEmoji(value: iconValue, color: iconColor, size: 20),
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
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (var i = 1; i <= 7; i++) ...[
                        _WeekDot(
                          label: progress.weekCompletion.containsKey(i) ? _weekdayLabels[i - 1] : '–',
                          on: progress.weekCompletion[i] ?? false,
                          color: colors.habits,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              toggled: completedToday,
              label: '${progress.habit.name}: ${completedToday ? 'mark incomplete today' : 'mark done today'}, ${progress.streakDays} day streak${atRisk ? ', at risk' : ''}',
              child: Tooltip(
                message: !progress.isScheduledToday ? 'Not scheduled today' : completedToday ? 'Mark incomplete today' : 'Mark done today',
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: progress.isScheduledToday ? () => onToggleToday(!completedToday) : null,
                    child: SizedBox(
                      width: 52,
                      height: 56,
                      child: ExcludeSemantics(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(completedToday ? Icons.check_circle_rounded : Icons.local_fire_department_rounded,
                            size: 24, color: !progress.isScheduledToday ? theme.disabledColor : completedToday ? colors.habits : accent),
                          Text(atRisk ? 'at risk' : '${progress.streakDays}d',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: accent)),
                        ],
                      )),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Open ${progress.habit.name}',
              onPressed: onTap,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 28,
              color: theme.colorScheme.onSurfaceVariant,
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
