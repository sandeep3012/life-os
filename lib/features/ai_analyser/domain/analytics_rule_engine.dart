import '../../finance/domain/budget_progress.dart';
import '../../goals/domain/goal_progress.dart';
import '../../habits/domain/habit_progress.dart';
import 'insight_draft.dart';

/// Pure rule-based insight generation: no DB or Riverpod access, just data
/// in, drafts out — every rule here is independently unit-testable, and the
/// whole function is the seam a future LLM-backed engine would replace.
List<InsightDraft> computeInsights({
  required List<BudgetProgress> budgets,
  required List<HabitProgress> habits,
  required int tasksCompletedThisWeek,
  required int tasksCompletedLastWeek,
  required List<GoalWithLinks> goals,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final drafts = <InsightDraft>[];

  drafts.addAll(_overspendInsights(budgets));
  drafts.addAll(_habitStreakRiskInsights(habits));
  drafts.addAll(_taskMomentumInsight(tasksCompletedThisWeek, tasksCompletedLastWeek));
  drafts.addAll(_goalPacingInsights(goals, today));

  return drafts;
}

Iterable<InsightDraft> _overspendInsights(List<BudgetProgress> budgets) sync* {
  for (final b in budgets) {
    if (!b.isOver || b.limitMinor == 0) continue;
    final overPct = ((b.spentMinor - b.limitMinor) / b.limitMinor * 100).round();
    final period = b.budget.period == 'weekly' ? 'week' : 'month';
    yield InsightDraft(
      type: 'overspend',
      severity: overPct >= 20 ? 'critical' : 'warning',
      title: '${b.category.name} spend is $overPct% over budget this $period',
      relatedModule: 'finance',
      relatedEntityId: b.budget.id,
    );
  }
}

Iterable<InsightDraft> _habitStreakRiskInsights(List<HabitProgress> habits) sync* {
  for (final h in habits) {
    if (!h.isAtRisk) continue;
    yield InsightDraft(
      type: 'streak_risk',
      severity: 'critical',
      title: '${h.habit.name} streak at risk — not logged today',
      relatedModule: 'habits',
      relatedEntityId: h.habit.id,
    );
  }
}

Iterable<InsightDraft> _taskMomentumInsight(int thisWeek, int lastWeek) sync* {
  if (lastWeek <= 0) return;
  final changePct = ((thisWeek - lastWeek) / lastWeek * 100).round();
  if (changePct >= 15) {
    yield InsightDraft(
      type: 'task_momentum',
      severity: 'good',
      title: 'Task completion rate up $changePct% this week — nice momentum',
      relatedModule: 'tasks',
    );
  } else if (changePct <= -15) {
    yield InsightDraft(
      type: 'task_momentum',
      severity: 'info',
      title: 'Task completion rate down ${changePct.abs()}% this week',
      relatedModule: 'tasks',
    );
  }
}

Iterable<InsightDraft> _goalPacingInsights(List<GoalWithLinks> goals, DateTime today) sync* {
  for (final g in goals) {
    final goal = g.goal;
    final targetDate = goal.targetDate;
    if (targetDate == null || goal.targetValue == null || goal.targetValue == 0) continue;

    final totalDays = targetDate.difference(goal.createdAt).inDays;
    if (totalDays <= 0) continue;
    final elapsedDays = today.difference(goal.createdAt).inDays.clamp(0, totalDays);
    final expectedRatio = elapsedDays / totalDays;
    if (expectedRatio <= 0) continue;

    if (g.ratio + 0.1 < expectedRatio) {
      yield InsightDraft(
        type: 'goal_behind',
        severity: 'warning',
        title: '"${goal.title}" is behind schedule for its target date',
        relatedModule: 'goals',
        relatedEntityId: goal.id,
      );
    } else if (g.ratio >= expectedRatio) {
      yield InsightDraft(
        type: 'goal_on_track',
        severity: 'info',
        title: 'On track to hit "${goal.title}" by target date at current pace',
        relatedModule: 'goals',
        relatedEntityId: goal.id,
      );
    }
  }
}
