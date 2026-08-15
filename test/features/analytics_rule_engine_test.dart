import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/ai_analyser/domain/analytics_rule_engine.dart';
import 'package:life_manager/features/finance/domain/budget_progress.dart';
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

      final drafts = computeInsights(
        budgets: [warningBudget, criticalBudget],
        habits: const [],
        tasksCompletedThisWeek: 0,
        tasksCompletedLastWeek: 0,
        goals: const [],
      );

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
      final drafts = computeInsights(
        budgets: [underBudget],
        habits: const [],
        tasksCompletedThisWeek: 0,
        tasksCompletedLastWeek: 0,
        goals: const [],
      );
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

      final drafts = computeInsights(
        budgets: const [],
        habits: [atRisk, safe],
        tasksCompletedThisWeek: 0,
        tasksCompletedLastWeek: 0,
        goals: const [],
      );

      expect(drafts, hasLength(1));
      expect(drafts.single.relatedEntityId, 'meditate');
      expect(drafts.single.severity, 'critical');
    });
  });

  group('task momentum rule', () {
    test('up 15%+ is good, down 15%+ is info, small change is silent', () {
      final up = computeInsights(
        budgets: const [],
        habits: const [],
        tasksCompletedThisWeek: 23,
        tasksCompletedLastWeek: 20, // +15%
        goals: const [],
      );
      expect(up.single.severity, 'good');

      final down = computeInsights(
        budgets: const [],
        habits: const [],
        tasksCompletedThisWeek: 17,
        tasksCompletedLastWeek: 20, // -15%
        goals: const [],
      );
      expect(down.single.severity, 'info');

      final flat = computeInsights(
        budgets: const [],
        habits: const [],
        tasksCompletedThisWeek: 21,
        tasksCompletedLastWeek: 20, // +5%
        goals: const [],
      );
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

      final drafts = computeInsights(
        budgets: const [],
        habits: const [],
        tasksCompletedThisWeek: 0,
        tasksCompletedLastWeek: 0,
        goals: [behind, onTrack, noTargetDate],
        now: now,
      );

      final byId = {for (final d in drafts) d.relatedEntityId: d};
      expect(byId['g1']!.type, 'goal_behind');
      expect(byId['g2']!.type, 'goal_on_track');
      expect(byId.containsKey('g3'), isFalse);
    });
  });
}
