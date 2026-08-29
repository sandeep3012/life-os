import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/icon_lookup.dart';
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
    // The at-risk signal always wins on the streak text below — only the
    // icon circle picks up the category's color/icon when uncategorized
    // wouldn't otherwise show one, same split as HabitTile.
    final accent = atRisk ? colors.critical : colors.habits;
    final category = progress.category;
    final categoryColor = category == null
        ? null
        : Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));
    final iconColor = categoryColor ?? accent;
    final doneToday = progress.weekCompletion[DateTime.now().weekday] ?? false;
    final icon = category == null ? Icons.local_fire_department_rounded : resolveIcon(category.icon);

    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.toggle();
            onToggle();
          },
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
                    color: iconColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedCrossFade(
                    firstChild: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: iconColor,
                    )
                        .animate()
                        .scale(
                          begin: doneToday ? const Offset(1.2, 1.2) : const Offset(1.0, 1.0),
                          end: const Offset(1.0, 1.0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                        ),
                    secondChild: Icon(
                      icon,
                      size: 18,
                      color: iconColor,
                    ),
                    crossFadeState: doneToday
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
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
