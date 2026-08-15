import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/utils/date_utils.dart';
import '../../finance/application/finance_providers.dart';
import '../../goals/application/goals_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../data/insights_repository.dart';
import '../domain/analytics_rule_engine.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(ref.watch(appDatabaseProvider));
});

/// Ordered worst-first so the most urgent condition is always the first
/// card: critical > warning > info > good.
const _severityRank = {'critical': 0, 'warning': 1, 'info': 2, 'good': 3};

final activeInsightsProvider = Provider<List<Insight>>((ref) {
  final insights = ref.watch(_activeInsightsStreamProvider).value ?? const [];
  final sorted = [...insights]
    ..sort((a, b) => (_severityRank[a.severity] ?? 9).compareTo(_severityRank[b.severity] ?? 9));
  return sorted;
});

final _activeInsightsStreamProvider = StreamProvider<List<Insight>>((ref) {
  return ref.watch(insightsRepositoryProvider).watchActiveInsights();
});

class AiAnalyserController {
  AiAnalyserController(this._ref);

  final Ref _ref;

  Future<void> refresh() async {
    // The aggregate providers below read watched streams' *current* value
    // synchronously — on a cold visit (nothing else has watched these
    // providers yet, e.g. refresh() running at app startup before any
    // screen has mounted), a StreamProvider with no active listener gets
    // torn down again right after this reads it once, before the
    // underlying Drift stream ever delivers its first value — so `.future`
    // would hang forever. Holding an explicit `listen` for the duration of
    // this call keeps each provider alive long enough to actually resolve.
    final subscriptions = [
      _ref.listen(accountsProvider, (_, _) {}),
      _ref.listen(transactionsProvider, (_, _) {}),
      _ref.listen(categoriesProvider, (_, _) {}),
      _ref.listen(budgetsProvider, (_, _) {}),
      _ref.listen(habitsListProvider, (_, _) {}),
      _ref.listen(habitLogsProvider, (_, _) {}),
      _ref.listen(allTasksProvider, (_, _) {}),
      _ref.listen(goalsListProvider, (_, _) {}),
      _ref.listen(allGoalLinksProvider, (_, _) {}),
      _ref.listen(billsProvider, (_, _) {}),
      _ref.listen(allGoalMilestonesProvider, (_, _) {}),
      _ref.listen(habitCategoriesProvider, (_, _) {}),
    ];
    try {
      await Future.wait([
        _ref.read(accountsProvider.future),
        _ref.read(transactionsProvider.future),
        _ref.read(categoriesProvider.future),
        _ref.read(budgetsProvider.future),
        _ref.read(habitsListProvider.future),
        _ref.read(habitLogsProvider.future),
        _ref.read(allTasksProvider.future),
        _ref.read(goalsListProvider.future),
        _ref.read(allGoalLinksProvider.future),
        _ref.read(billsProvider.future),
        _ref.read(allGoalMilestonesProvider.future),
        _ref.read(habitCategoriesProvider.future),
      ]);
    } finally {
      for (final subscription in subscriptions) {
        subscription.close();
      }
    }

    final tasks = _ref.read(allTasksProvider).value ?? const [];
    final now = DateTime.now();
    final thisWeekStart = startOfWeek(now);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    int completedInRange(DateTime start, DateTime end) {
      return tasks
          .where(
            (t) =>
                t.completedAt != null &&
                !t.completedAt!.isBefore(start) &&
                t.completedAt!.isBefore(end),
          )
          .length;
    }

    final bills = _ref.read(billsProvider).value ?? const [];
    final netWorthTrend = _ref.read(netWorthTrendProvider);
    final allMilestones = _ref.read(allGoalMilestonesProvider).value ?? const [];
    final milestonesByGoal = <String, List<GoalMilestone>>{};
    for (final m in allMilestones) {
      milestonesByGoal.putIfAbsent(m.goalId, () => []).add(m);
    }

    final drafts = computeInsights(
      budgets: _ref.read(budgetsWithProgressProvider),
      habits: _ref.read(habitsWithProgressProvider),
      tasksCompletedThisWeek: completedInRange(thisWeekStart, now),
      tasksCompletedLastWeek: completedInRange(lastWeekStart, thisWeekStart),
      goals: _ref.read(goalsWithLinksProvider),
      bills: bills,
      netWorthTrend: netWorthTrend,
      milestonesByGoal: milestonesByGoal,
      now: now,
    );

    await _ref.read(insightsRepositoryProvider).reconcile(drafts);
  }

  Future<void> dismiss(String id) => _ref.read(insightsRepositoryProvider).dismiss(id);
}

final aiAnalyserControllerProvider = Provider<AiAnalyserController>((ref) {
  return AiAnalyserController(ref);
});
