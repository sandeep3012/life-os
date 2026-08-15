import '../../../core/database/app_database.dart';
import '../../finance/domain/budget_progress.dart';
import '../../finance/domain/net_worth_point.dart';
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
  required List<Bill> bills,
  required List<NetWorthPoint> netWorthTrend,
  required Map<String, List<GoalMilestone>> milestonesByGoal,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final drafts = <InsightDraft>[];

  drafts.addAll(_overspendInsights(budgets));
  drafts.addAll(_habitStreakRiskInsights(habits));
  drafts.addAll(_taskMomentumInsight(tasksCompletedThisWeek, tasksCompletedLastWeek));
  drafts.addAll(_goalPacingInsights(goals, today));
  drafts.addAll(_billDueSoonInsights(bills, today));
  drafts.addAll(_netWorthTrendInsights(netWorthTrend));
  drafts.addAll(_goalMilestoneGapInsights(goals, milestonesByGoal, today));
  drafts.addAll(_habitCategoryRollupInsights(habits));

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

/// Approaching (not overdue) active bills within a week of their due date —
/// overdue bills are a distinct condition, out of scope here.
Iterable<InsightDraft> _billDueSoonInsights(List<Bill> bills, DateTime today) sync* {
  final todayOnly = DateTime(today.year, today.month, today.day);
  for (final b in bills) {
    if (!b.active) continue;
    final dueOnly = DateTime(b.dueDate.year, b.dueDate.month, b.dueDate.day);
    final daysUntilDue = dueOnly.difference(todayOnly).inDays;
    if (daysUntilDue < 0 || daysUntilDue > 7) continue;
    final amount = (b.amountMinor / 100).toStringAsFixed(2);
    final dueDesc = switch (daysUntilDue) {
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in $daysUntilDue days',
    };
    yield InsightDraft(
      type: 'bill_due_soon',
      severity: daysUntilDue <= 2 ? 'critical' : 'warning',
      title: '${b.name} (\$$amount) is due $dueDesc',
      relatedModule: 'finance',
      relatedEntityId: b.id,
    );
  }
}

/// Compares the two most recent points in the net worth trend (last
/// trailing month-start vs. now) — an aggregate, non-entity insight, same
/// as [_taskMomentumInsight].
Iterable<InsightDraft> _netWorthTrendInsights(List<NetWorthPoint> trend) sync* {
  if (trend.length < 2) return;
  final latest = trend.last;
  final previous = trend[trend.length - 2];
  if (previous.netWorthMinor == 0) return;
  final changePct = ((latest.netWorthMinor - previous.netWorthMinor) / previous.netWorthMinor.abs() * 100)
      .round();
  if (changePct <= -10) {
    yield InsightDraft(
      type: 'net_worth_decline',
      severity: changePct <= -20 ? 'critical' : 'warning',
      title: 'Net worth down ${changePct.abs()}% from last month',
      relatedModule: 'finance',
    );
  } else if (changePct >= 10) {
    yield InsightDraft(
      type: 'net_worth_decline',
      severity: 'good',
      title: 'Net worth up $changePct% from last month',
      relatedModule: 'finance',
    );
  }
}

/// A goal within 2 weeks of its deadline that has milestones defined but
/// none completed. Goals with no milestones at all don't participate — with
/// nothing defined there's nothing to be "behind" on. Distinct `type` from
/// goal_behind/goal_on_track: this is a milestone-completion signal, not a
/// currentValue/targetValue pacing signal, so a goal can carry both.
Iterable<InsightDraft> _goalMilestoneGapInsights(
  List<GoalWithLinks> goals,
  Map<String, List<GoalMilestone>> milestonesByGoal,
  DateTime today,
) sync* {
  for (final g in goals) {
    final goal = g.goal;
    final targetDate = goal.targetDate;
    if (targetDate == null) continue;
    final daysUntilTarget = targetDate.difference(today).inDays;
    if (daysUntilTarget < 0 || daysUntilTarget > 14) continue;

    final milestones = milestonesByGoal[goal.id] ?? const [];
    if (milestones.isEmpty) continue;
    if (milestones.any((m) => m.completed)) continue;

    yield InsightDraft(
      type: 'goal_milestone_gap',
      severity: daysUntilTarget <= 3 ? 'critical' : 'warning',
      title: '"${goal.title}" is due in $daysUntilTarget days with no milestones completed',
      relatedModule: 'goals',
      relatedEntityId: goal.id,
    );
  }
}

/// Flags a habit category where most/all habits are at risk today —
/// deliberately stricter than "most" since per-habit [_habitStreakRiskInsights]
/// already surfaces individual at-risk habits; this only adds value when the
/// pattern is category-wide. Categories under 3 habits are skipped since one
/// missed habit would otherwise swing the percentage too much to be meaningful.
Iterable<InsightDraft> _habitCategoryRollupInsights(List<HabitProgress> habits) sync* {
  final byCategory = <String, List<HabitProgress>>{};
  for (final h in habits) {
    final category = h.category;
    if (category == null) continue;
    byCategory.putIfAbsent(category.id, () => []).add(h);
  }

  for (final entry in byCategory.entries) {
    final categoryHabits = entry.value;
    if (categoryHabits.length < 3) continue;
    final atRiskCount = categoryHabits.where((h) => h.isAtRisk).length;
    final atRiskFraction = atRiskCount / categoryHabits.length;
    if (atRiskFraction < 0.75) continue;

    final categoryName = categoryHabits.first.category!.name;
    yield InsightDraft(
      type: 'habit_category_rollup',
      severity: atRiskFraction >= 1.0 ? 'critical' : 'warning',
      title: '$atRiskCount of ${categoryHabits.length} "$categoryName" habits are at risk today',
      relatedModule: 'habits',
      relatedEntityId: entry.key,
    );
  }
}
