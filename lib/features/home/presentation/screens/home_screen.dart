import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/motion.dart';
import '../../../../app/router/app_sidebar.dart';
import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/widgets/tappable.dart';
import '../../../ai_analyser/application/ai_analyser_providers.dart';
import '../../../ai_analyser/presentation/widgets/insight_card.dart';
import '../../../calendar/application/calendar_providers.dart';
import '../../../calendar/domain/calendar_item.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../habits/domain/habit_progress.dart';
import '../../../health/application/health_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../application/home_providers.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../widgets/now_hero_card.dart';
import '../widgets/habit_ring_tile.dart';

/// The dashboard, laid out as the design comp specifies: app bar, serif greeting,
/// the "now" hero, today's to-dos, a two-column habit grid, then "Coming up".
///
/// Screen padding is the comp's 20px horizontal. It does *not* add the comp's
/// 108px bottom padding, because this app's nav pill occupies the Scaffold's
/// `bottomNavigationBar` slot rather than floating over the content, so the
/// height is already reserved.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final todayTasks = ref.watch(todayTasksProvider);
    final habits = ref.watch(habitCheckInProvider);
    final upcoming = ref.watch(upcomingItemsProvider);
    final insights = ref.watch(activeInsightsProvider);
    final monthSpendMinor = ref.watch(monthSpendMinorProvider);
    final activeGoals = ref.watch(activeGoalCountProvider);
    final currencyCode = ref.watch(settingsProvider).currencyCode;

    final now = DateTime.now();
    // Habits have their own grid and tasks have their own list, so the hero
    // draws only from what no other section owns. Without this a task due today
    // renders twice on one screen — the same duplication rule
    // `upcomingItemsProvider` follows for the "Coming up" list.
    final todayAgenda =
        ref
            .watch(allCalendarItemsProvider)
            .where(
              (i) =>
                  isSameDay(i.date, now) &&
                  i.type != CalendarItemType.habit &&
                  i.type != CalendarItemType.task,
            )
            .toList()
          ..sort((a, b) => (a.time ?? a.date).compareTo(b.time ?? b.date));

    return Scaffold(
      drawer: const AppSidebar(),
      body: SafeArea(
        bottom: false,
        child:
            ListView(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Builder(
                        builder: (context) => AppTopBar(
                          centerText: DateFormat(
                            'EEE · d MMM yyyy',
                          ).format(now),
                          onMenu: () => Scaffold.of(context).openDrawer(),
                          onAvatar: () => context.go(RoutePaths.settings),
                        ),
                      ),
                    ),

                    _Greeting(text: _greeting(now), accent: scheme.secondary),
                    const SizedBox(height: 6),
                    Text(
                      _summaryLine(todayTasks, habits.length),
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 20),
                    _buildNowCard(
                      ref.watch(todayWorkoutProvider),
                      todayAgenda,
                      now,
                    ),

                    const SizedBox(height: 20),
                    _DashboardStatRail(
                      monthSpendMinor: monthSpendMinor,
                      currencyCode: currencyCode,
                      tasks: todayTasks,
                      activeGoals: activeGoals,
                    ),

                    if (todayTasks.tasks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: "Today's to-dos",
                        trailing: Tappable(
                          onTap: () => context.go(RoutePaths.tasksHabits),
                          semanticLabel: 'See all tasks',
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.accentInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      _TodayTaskList(tasks: todayTasks.tasks.take(4).toList()),
                    ],

                    if (habits.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionHeader(
                        title: 'Habits to keep',
                        trailing: Tappable(
                          onTap: () => context.go(RoutePaths.habitsOverview),
                          semanticLabel: 'See all habits',
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.accentInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      const _HabitGrid(),
                    ],

                    if (upcoming.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      SectionHeader(
                        title: 'Coming up',
                        trailing: Tappable(
                          onTap: () => context.go(RoutePaths.calendar),
                          semanticLabel: 'Open calendar',
                          child: Text(
                            'Calendar',
                            style: TextStyle(
                              fontFamily: AppFonts.sans,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colors.accentInk,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 11),
                      _UpcomingList(items: upcoming, now: now),
                    ],

                    if (insights.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Worth knowing'),
                      const SizedBox(height: 11),
                      InsightCard(
                        insight: insights.first,
                        onDismiss: () => ref
                            .read(aiAnalyserControllerProvider)
                            .dismiss(insights.first.id),
                      ),
                    ],

                    // The comp has no empty state — it's drawn with a full day of data —
                    // but a first-run dashboard needs to say something, and the hero's
                    // "Nothing scheduled" only speaks for the schedule.
                    if (todayTasks.tasks.isEmpty &&
                        habits.isEmpty &&
                        upcoming.isEmpty &&
                        insights.isEmpty) ...[
                      const SizedBox(height: 22),
                      Center(
                        child: Text(
                          'Your dashboard fills in as you go',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 14,
                            color: colors.text3,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
                .animate()
                .fadeIn(duration: AppMotion.screenEnter)
                .slideY(
                  begin: 0.02,
                  end: 0.0,
                  duration: AppMotion.screenEnter,
                  curve: AppMotion.standard,
                ),
      ),
    );
  }

  /// The comp's hero is a gym block, and that's what it shows when a training
  /// day is planned — live while the block's window contains the current time.
  /// With no session today it falls back to the next real thing on the
  /// schedule, then to an honest empty state.
  Widget _buildNowCard(
    TodayWorkout? workout,
    List<CalendarItem> agenda,
    DateTime now,
  ) {
    if (workout != null && workout.exercises.isNotEmpty) {
      final next = workout.nextExercise;
      final fmt = DateFormat('h:mm a');
      return NowHeroCard(
        overline: workout.isLive
            ? 'Now · ${fmt.format(workout.start)}–${fmt.format(workout.end)}'
            : 'Today · ${fmt.format(workout.start)}',
        kicker: workout.day.label,
        title: workout.day.focus.isEmpty
            ? workout.day.label
            : workout.day.focus,
        upNextLabel: next == null ? null : 'Up next',
        upNextValue: next == null
            ? null
            : next.scheme.isEmpty
            ? next.name
            : '${next.name} · ${next.scheme}',
        progress: workout.progress,
        progressLeft:
            'Exercise ${workout.doneCount + (next == null ? 0 : 1)} of ${workout.exercises.length}',
        progressRight: '${(workout.progress * 100).round()}% complete',
        live: workout.isLive,
      );
    }

    if (agenda.isEmpty) {
      return const NowHeroCard(
        overline: 'Today',
        title: 'Nothing scheduled',
        subtitle: 'Your day is clear. Anything you add shows up here.',
      );
    }

    final timed = agenda.where((i) => i.time != null).toList();

    // An item counts as live when now falls inside its window; items with no end
    // time are treated as an hour long, which is what the comp's 7:00–8:00 block
    // implies for a single-point entry.
    CalendarItem? live;
    for (final item in timed) {
      final start = item.time!;
      final end = item.endTime ?? start.add(const Duration(hours: 1));
      if (!start.isAfter(now) && end.isAfter(now)) {
        live = item;
        break;
      }
    }
    final isLive = live != null;

    final current =
        live ??
        timed.firstWhere(
          (i) => i.time!.isAfter(now),
          orElse: () => agenda.first,
        );
    final index = agenda.indexOf(current);
    final next = index >= 0 && index + 1 < agenda.length
        ? agenda[index + 1]
        : null;

    final start = current.time;
    final end = current.endTime;
    final fmt = DateFormat('h:mm a');

    String overline;
    if (isLive && start != null) {
      overline = end == null
          ? 'Now · ${fmt.format(start)}'
          : 'Now · ${fmt.format(start)}–${fmt.format(end)}';
    } else if (start != null) {
      overline = 'Next · ${fmt.format(start)}';
    } else {
      overline = 'Today';
    }

    double? progress;
    String? progressLeft;
    String? progressRight;
    if (isLive && start != null && end != null && end.isAfter(start)) {
      final total = end.difference(start).inSeconds;
      final done = now.difference(start).inSeconds.clamp(0, total);
      progress = done / total;
      progressLeft = '${index + 1} of ${agenda.length} today';
      progressRight = '${(progress * 100).round()}% through';
    } else if (agenda.length > 1) {
      progressLeft = '${index + 1} of ${agenda.length} today';
    }

    return NowHeroCard(
      overline: overline,
      kicker: _kickerFor(current.type),
      title: current.title,
      upNextLabel: next == null ? null : 'Up next',
      upNextValue: next?.title,
      progress: progress,
      progressLeft: progressLeft,
      progressRight: progressRight,
      live: isLive,
    );
  }

  static String _greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _summaryLine(TodayTasks tasks, int habitCount) {
    final parts = <String>[];
    if (tasks.remaining > 0) {
      parts.add(
        '${tasks.remaining} to-do${tasks.remaining == 1 ? '' : 's'} left',
      );
    }
    if (habitCount > 0) {
      parts.add('$habitCount habit${habitCount == 1 ? '' : 's'} to keep');
    }
    if (parts.isEmpty) return 'Nothing pending. Enjoy the quiet.';
    return parts.join(' · ');
  }

  static String _kickerFor(CalendarItemType type) => switch (type) {
    CalendarItemType.task => 'To-do',
    CalendarItemType.event => 'Calendar',
    CalendarItemType.bill => 'Scheduled',
    CalendarItemType.habit => 'Habit',
  };

  static IconData _iconFor(CalendarItemType type) => switch (type) {
    CalendarItemType.task => LucideIcons.circleCheck,
    CalendarItemType.event => LucideIcons.calendarDays,
    CalendarItemType.bill => LucideIcons.shield,
    CalendarItemType.habit => LucideIcons.repeat,
  };

  /// Matches the three row colours the comp actually renders in "Coming up":
  /// steel for the calendar row, amber for the scheduled expense, accent for the
  /// money movement.
  static Color _colorFor(CalendarItemType type, AppColors colors) =>
      switch (type) {
        CalendarItemType.task => colors.accentInk,
        CalendarItemType.event => colors.info,
        CalendarItemType.bill => colors.warning,
        CalendarItemType.habit => colors.habits,
      };

  /// Comp: `in 1h` / `in 3d`.
  static String _relative(DateTime target, DateTime now) {
    final diff = target.difference(now);
    if (diff.isNegative) return 'now';
    if (diff.inMinutes < 60) return 'in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'in ${diff.inHours}h';
    return 'in ${diff.inDays}d';
  }
}

/// Comp: 30px Newsreader w500, with the trailing period in the accent.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: 30,
      height: 1.06,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.3,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text),
          TextSpan(
            text: '.',
            style: TextStyle(color: accent),
          ),
        ],
      ),
    );
  }
}

/// A short horizontal summary rail. Each card is deliberately a single focused
/// number: it is quicker to scan than mixing finance, tasks and goals together.
class _DashboardStatRail extends StatelessWidget {
  const _DashboardStatRail({
    required this.monthSpendMinor,
    required this.currencyCode,
    required this.tasks,
    required this.activeGoals,
  });

  final int monthSpendMinor;
  final String currencyCode;
  final TodayTasks tasks;
  final int activeGoals;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _DashboardStatCard(
            icon: LucideIcons.walletCards,
            iconColor: context.appColors.warm,
            label: 'This month spent',
            value: formatMinor(
              monthSpendMinor,
              currencyCode: currencyCode,
              showDecimals: false,
            ),
            footer: DateFormat.MMMM().format(DateTime.now()),
            // A determinate bar keeps widget tests and reduced-motion devices
            // free of the indeterminate progress animation.
            progress: monthSpendMinor > 0 ? 1 : 0,
            onTap: () => context.go(RoutePaths.finance),
          ),
          const SizedBox(width: 12),
          _DashboardStatCard(
            icon: LucideIcons.listChecks,
            iconColor: context.appColors.tasks,
            label: 'Tasks today',
            value: '${tasks.doneCount} / ${tasks.total}',
            footer: tasks.remaining == 0
                ? 'All caught up'
                : '${tasks.remaining} remaining',
            progress: tasks.total == 0 ? 0 : tasks.doneCount / tasks.total,
            onTap: () => context.go(RoutePaths.tasksHabits),
          ),
          const SizedBox(width: 12),
          _DashboardStatCard(
            icon: LucideIcons.target,
            iconColor: context.appColors.goals,
            label: activeGoals == 1 ? 'Active goal' : 'Active goals',
            value: '$activeGoals',
            footer: activeGoals == 0
                ? 'Create your first goal'
                : 'Keep moving forward',
            progress: activeGoals == 0 ? 0 : 1,
            onTap: () => context.go(RoutePaths.goals),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.footer,
    required this.progress,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String footer;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 172,
      child: Tappable(
        onTap: onTap,
        haptic: TapHaptic.selection,
        semanticLabel: '$label: $value',
        child: SurfaceCard(
          padding: const EdgeInsets.all(15),
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(icon, size: 18, color: iconColor),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 27,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                footer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainer,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayTaskList extends ConsumerWidget {
  const _TodayTaskList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        children: [
          for (var index = 0; index < tasks.length; index++) ...[
            _TodayTaskRow(task: tasks[index]),
            if (index < tasks.length - 1)
              Divider(height: 1, indent: 66, color: scheme.outline),
          ],
        ],
      ),
    );
  }
}

class _TodayTaskRow extends ConsumerWidget {
  const _TodayTaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final done = task.status == 'done';
    final priority =
        task.priority[0].toUpperCase() + task.priority.substring(1);

    return Tappable(
      onTap: () => context.push(RoutePaths.taskDetail(task.id)),
      semanticLabel: 'Open task $task.title',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            IconButton(
              tooltip: done ? 'Mark task open' : 'Complete task',
              onPressed: () =>
                  ref.read(tasksControllerProvider).toggleDone(task),
              icon: Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: done ? scheme.primary : scheme.outline,
                    width: 2,
                  ),
                ),
                child: done
                    ? Icon(LucideIcons.check, size: 15, color: scheme.onPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the original compact two-column, two-row tile grid, with horizontal
/// paging when more than four habits are due today.
class _HabitGrid extends ConsumerWidget {
  const _HabitGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(habitCheckInProvider);
    final pages = <List<HabitProgress>>[];
    for (var index = 0; index < shown.length; index += 4) {
      pages.add(shown.skip(index).take(4).toList());
    }

    return SizedBox(
      height: 166,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 11) / 2;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: pages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 11),
            itemBuilder: (context, pageIndex) {
              final page = pages[pageIndex];
              return SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  children: [
                    for (
                      var rowIndex = 0;
                      rowIndex < page.length;
                      rowIndex += 2
                    )
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: rowIndex + 2 < page.length ? 10 : 0,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _tile(context, ref, page[rowIndex]),
                            ),
                            const SizedBox(width: 11),
                            SizedBox(
                              width: cardWidth,
                              child: rowIndex + 1 < page.length
                                  ? _tile(context, ref, page[rowIndex + 1])
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, HabitProgress progress) {
    final habit = progress.habit;
    final target = progress.weekCompletion.length;
    final doneThisWeek = progress.weekCompletion.values
        .where((done) => done)
        .length;
    final ratio = target <= 0 ? 0.0 : doneThisWeek / target;
    final doneToday = progress.weekCompletion[DateTime.now().weekday] ?? false;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;

    return HabitRingTile(
      name: habit.name,
      subtitle: '$doneThisWeek / $target this week',
      progress: ratio,
      complete: ratio >= 1,
      color: doneToday ? scheme.secondary : colors.critical,
      onTap: () =>
          ref.read(habitsControllerProvider).toggleToday(habit, !doneToday),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  const _UpcomingList({required this.items, required this.now});

  final List<CalendarItem> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tappable(
      onTap: () => context.go(RoutePaths.calendar),
      semanticLabel: 'Open calendar',
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        radius: 22,
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _UpcomingListRow(item: items[index], now: now),
              if (index < items.length - 1)
                Divider(height: 1, indent: 74, color: scheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpcomingListRow extends StatelessWidget {
  const _UpcomingListRow({required this.item, required this.now});

  final CalendarItem item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = HomeScreen._colorFor(item.type, context.appColors);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 47,
            child: Text(
              HomeScreen._relative(item.time ?? item.date, now),
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(HomeScreen._iconFor(item.type), size: 16, color: color),
        ],
      ),
    );
  }
}
