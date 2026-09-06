import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../ai_analyser/application/ai_analyser_providers.dart';
import '../../../ai_analyser/presentation/widgets/insight_card.dart';
import '../../../calendar/application/calendar_providers.dart';
import '../../../calendar/presentation/widgets/calendar_item_tile.dart';
import '../../../calendar/domain/calendar_item.dart';
import '../../../goals/application/goals_providers.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../../tasks/presentation/widgets/task_tile.dart';
import '../../application/home_providers.dart';
import '../widgets/habit_check_in_card.dart';
import '../widgets/stat_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    final insights = ref.watch(activeInsightsProvider);
    final weekSpend = ref.watch(weekSpendMinorProvider);
    final lastWeekSpend = ref.watch(lastWeekSpendMinorProvider);
    final todayTasks = ref.watch(todayTasksProvider);
    final habits = ref.watch(habitCheckInProvider);
    final activeGoals = ref.watch(activeGoalCountProvider);
    final upcoming = ref.watch(upcomingItemsProvider);
    final todayAgenda = ref.watch(allCalendarItemsProvider)
        .where((item) => isSameDay(item.date, DateTime.now()) && item.type != CalendarItemType.habit)
        .toList()
      ..sort((a, b) => (a.time ?? a.date).compareTo(b.time ?? b.date));
    final activeGoalList = (ref.watch(goalsListProvider).value ?? const [])
        .where((g) => g.status == 'active').toList();
    final goalProgress = activeGoalList.isEmpty ? 0.0 : activeGoalList.map((g) =>
      g.targetValue == null || g.targetValue == 0 ? 0.0 : (g.currentValue / g.targetValue!).clamp(0.0, 1.0)
    ).reduce((a, b) => a + b) / activeGoalList.length;
    final currencyCode = ref.watch(settingsProvider).currencyCode;

    final spendDelta = lastWeekSpend == 0
        ? null
        : (weekSpend - lastWeekSpend) / lastWeekSpend;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat.yMMMMEEEEd().format(DateTime.now()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(_greeting(), style: theme.textTheme.headlineSmall),
                ],
              ),
            ),

            if (insights.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: InsightCard(
                  insight: insights.first,
                  onDismiss: () =>
                      ref.read(aiAnalyserControllerProvider).dismiss(insights.first.id),
                ),
              ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08, end: 0),

            if (todayAgenda.isNotEmpty)
              _TodayAtAGlance(items: todayAgenda),

            SizedBox(
              height: 124,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  StatTile(
                    label: 'This week spend',
                    value: formatMinor(weekSpend, currencyCode: currencyCode, showDecimals: false),
                    icon: Icons.account_balance_wallet_rounded,
                    accent: colors.spend,
                    delta: spendDelta == null
                        ? null
                        : '${(spendDelta.abs() * 100).round()}% vs last week',
                    deltaColor: spendDelta == null
                        ? null
                        : (spendDelta >= 0 ? colors.critical : colors.good),
                    deltaIcon: spendDelta == null
                        ? null
                        : (spendDelta >= 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded),
                    progress: lastWeekSpend == 0 ? (weekSpend == 0 ? 0 : 1) : (weekSpend / lastWeekSpend).clamp(0.0, 1.0),
                    onTap: () => context.go(RoutePaths.finance),
                  ),
                  const SizedBox(width: 12),
                  StatTile(
                    label: 'Tasks today',
                    value: '${todayTasks.doneCount} / ${todayTasks.total}',
                    icon: Icons.checklist_rounded,
                    accent: colors.tasks,
                    delta: todayTasks.remaining == 0
                        ? 'all done'
                        : '${todayTasks.remaining} remaining',
                    progress: todayTasks.total == 0 ? 0 : todayTasks.doneCount / todayTasks.total,
                    onTap: () => context.go(RoutePaths.tasksHabits),
                  ),
                  const SizedBox(width: 12),
                  StatTile(
                    label: 'Active goals',
                    value: '$activeGoals',
                    icon: Icons.flag_rounded,
                    accent: colors.goals,
                    progress: goalProgress,
                    onTap: () => context.go(RoutePaths.goals),
                  ),
                ],
              ),
            ),

            if (todayTasks.tasks.isNotEmpty) ...[
              _SectionHeader(
                title: 'Today',
                actionLabel: 'See all',
                onAction: () => context.go(RoutePaths.tasksHabits),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        for (final task in todayTasks.tasks.take(3))
                          TaskTile(
                            key: ValueKey(task.id),
                            task: task,
                            onToggle: () =>
                                ref.read(tasksControllerProvider).toggleDone(task),
                            onDelete: () =>
                                ref.read(tasksControllerProvider).deleteTask(task),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (habits.isNotEmpty) ...[
              _SectionHeader(
                title: 'Habit check-in',
                actionLabel: 'See all',
                onAction: () => context.go(RoutePaths.tasksHabits),
              ),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: habits.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final progress = habits[index];
                    final doneToday =
                        progress.weekCompletion[DateTime.now().weekday] ?? false;
                    return HabitCheckInCard(
                      progress: progress,
                      onToggle: () => ref
                          .read(habitsControllerProvider)
                          .toggleToday(progress.habit, !doneToday),
                    );
                  },
                ),
              ),
            ],

            if (upcoming.isNotEmpty) ...[
              _SectionHeader(
                title: 'Upcoming',
                actionLabel: 'Calendar',
                onAction: () => context.go(RoutePaths.calendar),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(
                      children: [
                        for (final item in upcoming) CalendarItemTile(item: item),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (insights.isEmpty &&
                todayTasks.tasks.isEmpty &&
                habits.isEmpty &&
                upcoming.isEmpty &&
                weekSpend == 0)
              const _EmptyDashboard(),
          ],
        ),
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TodayAtAGlance extends StatelessWidget {
  const _TodayAtAGlance({required this.items});

  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = items.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today at a glance',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.appColors.warning,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      SizedBox(
                        width: 82,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(width: 7, height: 7, decoration: BoxDecoration(
                                color: _itemColor(context, visible[i].type), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(
                                visible[i].time == null ? 'Any time' : DateFormat.jm().format(visible[i].time!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              ),
                            ]),
                            const SizedBox(height: 3),
                            Text(
                              visible[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != visible.length - 1)
                        Container(
                          width: 1,
                          height: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: theme.colorScheme.outlineVariant,
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

  Color _itemColor(BuildContext context, CalendarItemType type) => switch (type) {
    CalendarItemType.event => context.appColors.tasks,
    CalendarItemType.bill => context.appColors.warning,
    CalendarItemType.task => context.appColors.goals,
    CalendarItemType.habit => context.appColors.good,
  };
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'Your dashboard fills in as you go',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Add a task, log a habit, or record a transaction to see it summarised here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
