import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/ai_analyser/domain/analytics_rule_engine.dart';
import 'package:life_manager/features/ai_analyser/domain/insight_draft.dart';
import 'package:life_manager/features/finance/domain/budget_progress.dart';
import 'package:life_manager/features/finance/domain/net_worth_point.dart';
import 'package:life_manager/features/goals/domain/goal_progress.dart';
import 'package:life_manager/features/habits/domain/habit_progress.dart';

Category _category(String name) => Category(
  id: name,
  name: name,
  icon: 'label',
  colorHex: '#000000',
  kind: 'expense',
  createdAt: DateTime(2026),
);

Category _habitCategory(String id, String name) => Category(
  id: id,
  name: name,
  icon: 'label',
  colorHex: '#000000',
  kind: 'habit',
  createdAt: DateTime(2026),
);

Budget _budget({required String id, required String period, required int limitMinor}) => Budget(
  id: id,
  categoryId: id,
  period: period,
  limitMinor: limitMinor,
  startDate: DateTime(2026, 7),
  effectiveMonth: DateTime(2026, 7),
  active: true,
  createdAt: DateTime(2026, 7),
);

Habit _habit(String id) => Habit(
  id: id,
  name: id,
  frequency: 'daily',
  targetPerWeek: 7,
  archived: false,
  reminderEnabled: false,
  reminderMode: 'notification',
  createdAt: DateTime(2026),
);

Goal _goal({
  required String id,
  required String title,
  required double targetValue,
  required double currentValue,
  DateTime? targetDate,
  DateTime? createdAt,
}) => Goal(
  id: id,
  title: title,
  type: 'generic',
  targetValue: targetValue,
  currentValue: currentValue,
  status: 'active',
  targetDate: targetDate,
  reminderEnabled: false,
  reminderMode: 'notification',
  reminderDaysBefore: 0,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
);

Bill _bill({required String id, required DateTime dueDate, bool active = true}) => Bill(
  id: id,
  name: id,
  amountMinor: 15000,
  dueDate: dueDate,
  frequency: 'once',
  reminderEnabled: true,
  reminderMode: 'notification',
  reminderDaysBefore: 0,
  active: active,
  createdAt: DateTime(2026, 1, 1),
);

GoalMilestone _milestone({required String goalId, bool completed = false}) => GoalMilestone(
  id: '$goalId-milestone-${completed ? 'done' : 'todo'}',
  goalId: goalId,
  title: 'Milestone',
  completed: completed,
  sortOrder: 0,
  createdAt: DateTime(2026, 1, 1),
);

NetWorthPoint _netWorthPoint({required DateTime date, required int netWorthMinor}) =>
    NetWorthPoint(date: date, assetsMinor: netWorthMinor, liabilitiesMinor: 0);

List<InsightDraft> _compute({
  List<BudgetProgress> budgets = const [],
  List<HabitProgress> habits = const [],
  int tasksCompletedThisWeek = 0,
  int tasksCompletedLastWeek = 0,
  List<GoalWithLinks> goals = const [],
  List<Bill> bills = const [],
  List<NetWorthPoint> netWorthTrend = const [],
  Map<String, List<GoalMilestone>> milestonesByGoal = const {},
  DateTime? now,
}) {
  return computeInsights(
    budgets: budgets,
    habits: habits,
    tasksCompletedThisWeek: tasksCompletedThisWeek,
    tasksCompletedLastWeek: tasksCompletedLastWeek,
    goals: goals,
    bills: bills,
    netWorthTrend: netWorthTrend,
    milestonesByGoal: milestonesByGoal,
    now: now,
  );
}

void main() {
  group('overspend rule', () {
    test('warning under 20% over, critical at/above 20% over', () {
      final warningBudget = BudgetProgress(
        budget: _budget(id: 'dining', period: 'monthly', limitMinor: 10000),
        category: _category('Dining'),
        spentMinor: 11000, // 10% over
      );
      final criticalBudget = BudgetProgress(
        budget: _budget(id: 'groceries', period: 'weekly', limitMinor: 10000),
        category: _category('Groceries'),
        spentMinor: 13000, // 30% over
      );

      final drafts = _compute(budgets: [warningBudget, criticalBudget]);

      final byCategory = {for (final d in drafts) d.relatedEntityId: d};
      expect(byCategory['dining']!.severity, 'warning');
      expect(byCategory['groceries']!.severity, 'critical');
      expect(byCategory['groceries']!.title, contains('week'));
    });

    test('no insight when under budget', () {
      final underBudget = BudgetProgress(
        budget: _budget(id: 'rent', period: 'monthly', limitMinor: 10000),
        category: _category('Rent'),
        spentMinor: 5000,
      );
      final drafts = _compute(budgets: [underBudget]);
      expect(drafts, isEmpty);
    });
  });

  group('habit streak risk rule', () {
    test('flags a habit with an active streak not logged today', () {
      final atRisk = HabitProgress(habit: _habit('meditate'), streakDays: 5, weekCompletion: const {});
      final safe = HabitProgress(
        habit: _habit('workout'),
        streakDays: 5,
        weekCompletion: {DateTime.now().weekday: true},
      );

      final drafts = _compute(habits: [atRisk, safe]);

      expect(drafts, hasLength(1));
      expect(drafts.single.relatedEntityId, 'meditate');
      expect(drafts.single.severity, 'critical');
    });
  });

  group('task momentum rule', () {
    test('up 15%+ is good, down 15%+ is info, small change is silent', () {
      final up = _compute(tasksCompletedThisWeek: 23, tasksCompletedLastWeek: 20); // +15%
      expect(up.single.severity, 'good');

      final down = _compute(tasksCompletedThisWeek: 17, tasksCompletedLastWeek: 20); // -15%
      expect(down.single.severity, 'info');

      final flat = _compute(tasksCompletedThisWeek: 21, tasksCompletedLastWeek: 20); // +5%
      expect(flat, isEmpty);
    });
  });

  group('goal pacing rule', () {
    test('behind schedule vs on track vs no target date', () {
      final now = DateTime(2026, 7, 21); // day 20 of a 40-day goal -> 50% expected
      final behind = GoalWithLinks(
        goal: _goal(
          id: 'g1',
          title: 'Read 24 books',
          targetValue: 24,
          currentValue: 5, // way under 50%
          targetDate: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 7, 1),
        ),
        links: const [],
      );
      final onTrack = GoalWithLinks(
        goal: _goal(
          id: 'g2',
          title: 'Emergency fund',
          targetValue: 200000,
          currentValue: 120000, // 60%, ahead of 50%
          targetDate: DateTime(2026, 8, 10),
          createdAt: DateTime(2026, 7, 1),
        ),
        links: const [],
      );
      final noTargetDate = GoalWithLinks(
        goal: _goal(id: 'g3', title: 'Someday goal', targetValue: 10, currentValue: 1),
        links: const [],
      );

      final drafts = _compute(goals: [behind, onTrack, noTargetDate], now: now);

      final byId = {for (final d in drafts) d.relatedEntityId: d};
      expect(byId['g1']!.type, 'goal_behind');
      expect(byId['g2']!.type, 'goal_on_track');
      expect(byId.containsKey('g3'), isFalse);
    });
  });

  group('bill due soon rule', () {
    final today = DateTime(2026, 3, 10);

    test('happy path: due in 5 days is a warning', () {
      final drafts = _compute(bills: [_bill(id: 'b1', dueDate: today.add(const Duration(days: 5)))], now: today);
      expect(drafts, hasLength(1));
      expect(drafts.single.severity, 'warning');
      expect(drafts.single.relatedEntityId, 'b1');
    });

    test('boundary: 2 days is critical, 3 days is warning', () {
      final drafts = _compute(
        bills: [
          _bill(id: 'soon', dueDate: today.add(const Duration(days: 2))),
          _bill(id: 'later', dueDate: today.add(const Duration(days: 3))),
        ],
        now: today,
      );
      final byId = {for (final d in drafts) d.relatedEntityId: d};
      expect(byId['soon']!.severity, 'critical');
      expect(byId['later']!.severity, 'warning');
    });

    test('no insight beyond 7 days, for inactive bills, or overdue bills', () {
      final drafts = _compute(
        bills: [
          _bill(id: 'far', dueDate: today.add(const Duration(days: 8))),
          _bill(id: 'inactive', dueDate: today.add(const Duration(days: 1)), active: false),
          _bill(id: 'overdue', dueDate: today.subtract(const Duration(days: 1))),
        ],
        now: today,
      );
      expect(drafts, isEmpty);
    });
  });

  group('net worth trend rule', () {
    test('happy path: -15% is a warning', () {
      final drafts = _compute(
        netWorthTrend: [
          _netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 100000),
          _netWorthPoint(date: DateTime(2026, 2, 1), netWorthMinor: 85000),
        ],
      );
      expect(drafts.single.severity, 'warning');
      expect(drafts.single.relatedEntityId, isNull);
    });

    test('boundary: exactly -10% present, -9% none, exactly -20% critical', () {
      final atThreshold = _compute(
        netWorthTrend: [
          _netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 100000),
          _netWorthPoint(date: DateTime(2026, 2, 1), netWorthMinor: 90000),
        ],
      );
      expect(atThreshold, hasLength(1));

      final belowThreshold = _compute(
        netWorthTrend: [
          _netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 100000),
          _netWorthPoint(date: DateTime(2026, 2, 1), netWorthMinor: 91000),
        ],
      );
      expect(belowThreshold, isEmpty);

      final critical = _compute(
        netWorthTrend: [
          _netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 100000),
          _netWorthPoint(date: DateTime(2026, 2, 1), netWorthMinor: 80000),
        ],
      );
      expect(critical.single.severity, 'critical');
    });

    test('no insight with fewer than 2 points or a zero-baseline previous point', () {
      final onePoint = _compute(
        netWorthTrend: [_netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 100000)],
      );
      expect(onePoint, isEmpty);

      final zeroBaseline = _compute(
        netWorthTrend: [
          _netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 0),
          _netWorthPoint(date: DateTime(2026, 2, 1), netWorthMinor: 5000),
        ],
      );
      expect(zeroBaseline, isEmpty);
    });

    test('a rise of 10%+ is a good-severity draft', () {
      final drafts = _compute(
        netWorthTrend: [
          _netWorthPoint(date: DateTime(2026, 1, 1), netWorthMinor: 100000),
          _netWorthPoint(date: DateTime(2026, 2, 1), netWorthMinor: 115000),
        ],
      );
      expect(drafts.single.severity, 'good');
    });
  });

  group('goal milestone gap rule', () {
    final today = DateTime(2026, 3, 10);

    GoalWithLinks goalWithDeadline(String id, DateTime targetDate) => GoalWithLinks(
      goal: _goal(id: id, title: id, targetValue: 10, currentValue: 1, targetDate: targetDate),
      links: const [],
    );

    // These fixtures also satisfy _goalPacingInsights (targetValue/currentValue
    // are set), so filter to this rule's `type` rather than asserting on the
    // whole draft list — the pacing insight firing alongside is expected,
    // not a bug.
    Iterable<InsightDraft> gapDrafts(List<InsightDraft> all) =>
        all.where((d) => d.type == 'goal_milestone_gap');

    test('happy path: 10 days out, no milestones completed', () {
      final goal = goalWithDeadline('g1', today.add(const Duration(days: 10)));
      final drafts = gapDrafts(
        _compute(goals: [goal], milestonesByGoal: {'g1': [_milestone(goalId: 'g1')]}, now: today),
      );
      expect(drafts.single.severity, 'warning');
      expect(drafts.single.relatedEntityId, 'g1');
    });

    test('boundary: 3 days critical, 4 days warning, 14 days present, 15 days none', () {
      final drafts = gapDrafts(
        _compute(
          goals: [
            goalWithDeadline('critical', today.add(const Duration(days: 3))),
            goalWithDeadline('warning', today.add(const Duration(days: 4))),
            goalWithDeadline('edge', today.add(const Duration(days: 14))),
            goalWithDeadline('tooFar', today.add(const Duration(days: 15))),
          ],
          milestonesByGoal: {
            'critical': [_milestone(goalId: 'critical')],
            'warning': [_milestone(goalId: 'warning')],
            'edge': [_milestone(goalId: 'edge')],
            'tooFar': [_milestone(goalId: 'tooFar')],
          },
          now: today,
        ),
      );
      final byId = {for (final d in drafts) d.relatedEntityId: d};
      expect(byId['critical']!.severity, 'critical');
      expect(byId['warning']!.severity, 'warning');
      expect(byId.containsKey('edge'), isTrue);
      expect(byId.containsKey('tooFar'), isFalse);
    });

    test('no insight with no milestones, a completed milestone, no targetDate, or overdue', () {
      final noMilestones = goalWithDeadline('noMilestones', today.add(const Duration(days: 5)));
      final hasCompleted = goalWithDeadline('hasCompleted', today.add(const Duration(days: 5)));
      final noTargetDate = GoalWithLinks(
        goal: _goal(id: 'noTargetDate', title: 'x', targetValue: 10, currentValue: 1),
        links: const [],
      );
      final overdue = goalWithDeadline('overdue', today.subtract(const Duration(days: 1)));

      final drafts = gapDrafts(
        _compute(
          goals: [noMilestones, hasCompleted, noTargetDate, overdue],
          milestonesByGoal: {
            'hasCompleted': [_milestone(goalId: 'hasCompleted', completed: true)],
            'overdue': [_milestone(goalId: 'overdue')],
          },
          now: today,
        ),
      );
      expect(drafts, isEmpty);
    });
  });

  group('habit category rollup rule', () {
    HabitProgress progressIn(String id, String categoryId, {required bool atRisk}) => HabitProgress(
      habit: _habit(id),
      streakDays: atRisk ? 5 : 0,
      weekCompletion: atRisk ? const {} : {DateTime.now().weekday: true},
      category: _habitCategory(categoryId, categoryId),
    );

    // At-risk habits also satisfy _habitStreakRiskInsights individually, so
    // filter to this rule's `type` — the per-habit insight firing alongside
    // is expected, not a bug.
    Iterable<InsightDraft> rollupDrafts(List<InsightDraft> all) =>
        all.where((d) => d.type == 'habit_category_rollup');

    test('happy path: 4 habits, 3 at risk (75%) is a warning', () {
      final drafts = rollupDrafts(
        _compute(
          habits: [
            progressIn('h1', 'fitness', atRisk: true),
            progressIn('h2', 'fitness', atRisk: true),
            progressIn('h3', 'fitness', atRisk: true),
            progressIn('h4', 'fitness', atRisk: false),
          ],
        ),
      );
      expect(drafts.single.severity, 'warning');
      expect(drafts.single.relatedEntityId, 'fitness');
    });

    test('boundary: exactly 75% present, below 75% none, 100% critical', () {
      final below = rollupDrafts(
        _compute(
          habits: [
            progressIn('h1', 'a', atRisk: true),
            progressIn('h2', 'a', atRisk: false),
            progressIn('h3', 'a', atRisk: false),
          ],
        ),
      );
      expect(below, isEmpty);

      final allAtRisk = rollupDrafts(
        _compute(
          habits: [
            progressIn('h1', 'b', atRisk: true),
            progressIn('h2', 'b', atRisk: true),
            progressIn('h3', 'b', atRisk: true),
          ],
        ),
      );
      expect(allAtRisk.single.severity, 'critical');
    });

    test('no insight below the size-3 minimum, for uncategorized habits, or none at risk', () {
      final tooSmall = rollupDrafts(
        _compute(habits: [progressIn('h1', 'c', atRisk: true), progressIn('h2', 'c', atRisk: true)]),
      );
      expect(tooSmall, isEmpty);

      final uncategorized = HabitProgress(habit: _habit('h1'), streakDays: 5, weekCompletion: const {});
      final none = rollupDrafts(_compute(habits: [uncategorized, uncategorized, uncategorized]));
      expect(none, isEmpty);

      final noneAtRisk = _compute(
        habits: [
          progressIn('h1', 'd', atRisk: false),
          progressIn('h2', 'd', atRisk: false),
          progressIn('h3', 'd', atRisk: false),
        ],
      );
      expect(noneAtRisk, isEmpty);
    });
  });
}
