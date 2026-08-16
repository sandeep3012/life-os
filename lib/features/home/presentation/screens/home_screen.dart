import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../ai_analyser/application/ai_analyser_providers.dart';
import '../../../ai_analyser/presentation/widgets/insight_card.dart';
import '../../../calendar/presentation/widgets/calendar_item_tile.dart';
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
    final averageStreak = ref.watch(averageStreakDaysProvider);
    final activeGoals = ref.watch(activeGoalCountProvider);
    final upcoming = ref.watch(upcomingItemsProvider);
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

            SizedBox(
              height: 108,
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
                    onTap: () => context.go(RoutePaths.tasksHabits),
                  ),
                  const SizedBox(width: 12),
                  StatTile(
                    label: 'Habit streaks',
                    value: '${averageStreak}d avg',
                    icon: Icons.local_fire_department_rounded,
                    accent: colors.habits,
                    delta: '${habits.length} tracked',
                    onTap: () => context.go(RoutePaths.tasksHabits),
                  ),
                  const SizedBox(width: 12),
                  StatTile(
                    label: 'Active goals',
                    value: '$activeGoals',
                    icon: Icons.flag_rounded,
                    accent: colors.goals,
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
