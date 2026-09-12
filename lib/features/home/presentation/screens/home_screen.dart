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
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../ai_analyser/application/ai_analyser_providers.dart';
import '../../../ai_analyser/presentation/widgets/insight_card.dart';
import '../../../calendar/application/calendar_providers.dart';
import '../../../calendar/domain/calendar_item.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../habits/domain/habit_progress.dart';
import '../../../health/application/health_providers.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../application/home_providers.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../widgets/habit_ring_tile.dart';
import '../widgets/now_hero_card.dart';
import '../widgets/todo_row.dart';
import '../widgets/upcoming_row.dart';

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

    final now = DateTime.now();
    // Habits have their own grid and tasks have their own list, so the hero
    // draws only from what no other section owns. Without this a task due today
    // renders twice on one screen — the same duplication rule
    // `upcomingItemsProvider` follows for the "Coming up" list.
    final todayAgenda = ref
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: DateFormat('EEE · d MMM yyyy').format(now),
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
            _buildNowCard(ref.watch(todayWorkoutProvider), todayAgenda, now),

            if (todayTasks.tasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeader(
                title: "Today's to-dos",
                trailing: Text(
                  '${todayTasks.doneCount} of ${todayTasks.total} done',
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 11),
              for (final task in todayTasks.tasks.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: TodoRow(
                    key: ValueKey(task.id),
                    title: task.title,
                    done: task.status == 'done',
                    time: task.dueDate == null
                        ? 'No date'
                        : DateFormat('h:mm a').format(task.dueDate!),
                    dotColor: colors.tasks,
                    onToggle: () =>
                        ref.read(tasksControllerProvider).toggleDone(task),
                  ),
                ),
            ],

            if (habits.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionHeader(title: 'Habits to keep'),
              const SizedBox(height: 11),
              const _HabitGrid(),
            ],

            if (upcoming.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionHeader(title: 'Coming up'),
              const SizedBox(height: 11),
              for (final item in upcoming)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: UpcomingRow(
                    icon: _iconFor(item.type),
                    color: _colorFor(item.type, colors),
                    title: item.title,
                    subtitle: item.subtitle,
                    trailing: _relative(item.time ?? item.date, now),
                    onTap: () => context.go(RoutePaths.calendar),
                  ),
                ),
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
        ).animate().fadeIn(duration: AppMotion.screenEnter).slideY(
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
        title: workout.day.focus.isEmpty ? workout.day.label : workout.day.focus,
        upNextLabel: next == null ? null : 'Up next',
        upNextValue: next == null
            ? null
            : next.scheme.isEmpty ? next.name : '${next.name} · ${next.scheme}',
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

    final current = live ??
        timed.firstWhere(
          (i) => i.time!.isAfter(now),
          orElse: () => agenda.first,
        );
    final index = agenda.indexOf(current);
    final next = index >= 0 && index + 1 < agenda.length ? agenda[index + 1] : null;

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
      parts.add('${tasks.remaining} to-do${tasks.remaining == 1 ? '' : 's'} left');
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
          TextSpan(text: '.', style: TextStyle(color: accent)),
        ],
      ),
    );
  }
}

/// Comp: a 2-column grid at 11px gaps. Built as rows rather than a GridView so it
/// sizes to content inside the parent [ListView].
class _HabitGrid extends ConsumerWidget {
  const _HabitGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(habitCheckInProvider).take(4).toList();
    final rows = <Widget>[];

    for (var i = 0; i < shown.length; i += 2) {
      final left = shown[i];
      final right = i + 1 < shown.length ? shown[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < shown.length ? 11 : 0),
          // IntrinsicHeight is what makes `stretch` legal here: inside a
          // ListView the Row's height is unbounded, and stretching against an
          // unbounded constraint asserts. It also gives the pair the equal
          // heights the comp's grid shows when one label wraps and the other
          // doesn't.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tile(ref, left)),
                const SizedBox(width: 11),
                Expanded(
                  child: right == null ? const SizedBox() : _tile(ref, right),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _tile(WidgetRef ref, HabitProgress progress) {
    final habit = progress.habit;
    final target = habit.targetPerWeek;
    final doneThisWeek =
        progress.weekCompletion.values.where((done) => done).length;
    final ratio = target <= 0 ? 0.0 : doneThisWeek / target;
    final doneToday =
        progress.weekCompletion[DateTime.now().weekday] ?? false;

    return HabitRingTile(
      name: habit.name,
      subtitle: '$doneThisWeek / $target this week',
      progress: ratio,
      complete: ratio >= 1,
      onTap: () =>
          ref.read(habitsControllerProvider).toggleToday(habit, !doneToday),
    );
  }
}
