import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/dashed_action_button.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';
import '../../application/habit_consistency_providers.dart';
import '../../application/habits_providers.dart';
import '../../domain/habit_progress.dart';
import '../widgets/quick_add_habit_sheet.dart';

/// The comp's Habits screen: a `CONSISTENCY · THIS WEEK` headline over a
/// seven-day strip, then a card per habit carrying a progress ring, a streak
/// pill, the week's dots and a check-off button, closing with a dashed
/// "Build a new habit" row.
///
/// The comp's ring tracks a per-day counter and its button increments it. This
/// app models habits as done/not-done per day against `targetPerWeek`, so the
/// ring shows week completion and the button toggles today — the same shape of
/// interaction against the data the schema actually holds.
class HabitsOverviewScreen extends ConsumerWidget {
  const HabitsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final habits = ref.watch(habitsWithProgressProvider);
    final consistency = ref.watch(habitConsistencyProvider);
    final doneToday = habits
        .where((h) => h.weekCompletion[DateTime.now().weekday] ?? false)
        .length;

    return Scaffold(
      drawer: const AppSidebar(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Habits',
                  centerIsTitle: true,
                  showTrailing: false,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),

            Overline('Consistency · this week', color: colors.text3, letterSpacing: 0.3),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(consistency.ratio * 100).round()}%',
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 42,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
                if (consistency.deltaPoints != null) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          consistency.deltaPoints! >= 0
                              ? LucideIcons.arrowUp
                              : LucideIcons.arrowDown,
                          size: 14,
                          color: consistency.deltaPoints! >= 0
                              ? colors.accentInk
                              : colors.warm,
                        ),
                        Text(
                          '${consistency.deltaPoints!.abs().round()} pts',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: consistency.deltaPoints! >= 0
                                ? colors.accentInk
                                : colors.warm,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              habits.isEmpty
                  ? 'No habits yet — build your first one below.'
                  : '${consistency.completedThisWeek} of '
                      '${consistency.targetThisWeek} check-ins logged this week',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 13.5,
                color: scheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),
            _WeekStrip(counts: consistency.dayCounts, habitCount: habits.length),

            if (habits.isNotEmpty) ...[
              const SizedBox(height: 22),
              SectionHeader(
                title: 'Today',
                trailing: Text(
                  '$doneToday of ${habits.length} done',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              for (final progress in habits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HabitCard(
                    key: ValueKey(progress.habit.id),
                    progress: progress,
                  ),
                ),
            ],

            const SizedBox(height: 2),
            DashedActionButton(
              label: 'Build a new habit',
              onTap: () async {
                final categories =
                    ref.read(habitCategoriesProvider).value ?? const [];
                final result =
                    await showQuickAddHabitSheet(context, categories: categories);
                if (result == null) return;
                await ref.read(habitsControllerProvider).addHabit(
                  result.name,
                  categoryId: result.categoryId,
                  reminderEnabled: result.reminderEnabled,
                  reminderHour: result.reminderHour,
                  reminderMinute: result.reminderMinute,
                  reminderMode: result.reminderMode,
                );
              },
            ),
          ],
        ).animate().fadeIn(duration: AppMotion.screenEnter).slideY(
              begin: 0.02,
              end: 0.0,
              duration: AppMotion.screenEnter,
              curve: AppMotion.standard,
            ),
      ),
    );
  }
}

/// Comp: a radius-20 card holding seven columns — weekday initial over a 30px
/// radius-10 box carrying the date, filled in proportion to that day's check-ins.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.counts, required this.habitCount});

  final Map<int, int> counts;
  final int habitCount;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final weekStart = startOfWeek(DateTime.now());
    final today = dateOnly(DateTime.now());

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      radius: 20,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = weekStart.add(Duration(days: i));
                  final done = counts[i + 1] ?? 0;
                  final isToday = day == today;
                  final future = day.isAfter(today);
                  final complete = habitCount > 0 && done >= habitCount;

                  final Color background;
                  final Color border;
                  final Color ink;
                  if (complete) {
                    background = scheme.secondary;
                    border = scheme.secondary;
                    ink = scheme.onPrimary;
                  } else if (done > 0) {
                    background = colors.accentSoft;
                    border = scheme.secondary;
                    ink = colors.accentInk;
                  } else {
                    background = Colors.transparent;
                    border = scheme.outline;
                    ink = future ? colors.text3 : scheme.onSurfaceVariant;
                  }

                  return Column(
                    children: [
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isToday ? colors.accentInk : colors.text3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: background,
                          border: Border.all(color: border, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: AppFonts.numeric,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: ink,
                            fontFeatures: AppFonts.tabular,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Comp: radius-20 card — a 46px ring, the name beside a streak pill, a caption,
/// a row of seven week dots, and a 44px radius-15 check-off button that shows a
/// plus until today is logged and a tick after.
class _HabitCard extends ConsumerWidget {
  const _HabitCard({super.key, required this.progress});

  final HabitProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    final habit = progress.habit;
    final target = habit.targetPerWeek;
    final done = progress.weekCompletion.values.where((v) => v).length;
    final ratio = target <= 0 ? 0.0 : done / target;
    final doneToday = progress.weekCompletion[DateTime.now().weekday] ?? false;

    final accent = progress.category == null
        ? scheme.secondary
        : Color(
            int.parse(progress.category!.colorHex.replaceFirst('#', '0xFF')),
          );

    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 20,
      child: Row(
        children: [
          ProgressRing(
            progress: ratio,
            size: 46,
            strokeWidth: 5,
            color: accent,
            child: Text(
              ratio >= 1 ? '✓' : '${(ratio * 100).round()}%',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (progress.streakDays > 0) ...[
                      const SizedBox(width: 7),
                      Container(
                        height: 19,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.flame,
                              size: 11,
                              color: accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${progress.streakDays}',
                              style: TextStyle(
                                fontFamily: AppFonts.sans,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$done / $target this week',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: colors.text3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var day = 1; day <= 7; day++) ...[
                      if (day > 1) const SizedBox(width: 4),
                      Container(
                        width: 13,
                        height: 6,
                        decoration: BoxDecoration(
                          color: (progress.weekCompletion[day] ?? false)
                              ? accent
                              : scheme.outline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tappable(
            haptic: TapHaptic.light,
            semanticLabel: doneToday
                ? 'Mark ${habit.name} not done today'
                : 'Mark ${habit.name} done today',
            selected: doneToday,
            onTap: () => ref
                .read(habitsControllerProvider)
                .toggleToday(habit, !doneToday),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: doneToday ? accent : colors.accentSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                doneToday ? LucideIcons.check : LucideIcons.plus,
                size: 19,
                color: doneToday ? scheme.onPrimary : colors.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


