import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/reminders/reminder_status.dart';
import 'package:life_manager/features/finance/domain/finance_report.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';
import 'package:life_manager/features/goals/domain/automatic_goal_progress.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'filtered reports compare same scope and custom ranges include the last day',
    () async {
      for (final item in [
        ('a', DateTime(2026, 9, 1), -100),
        ('a', DateTime(2026, 9, 2, 23), -200),
        ('a', DateTime(2026, 8, 31), -50),
        ('a', DateTime(2026, 9, 3), -999),
        ('b', DateTime(2026, 9, 1), -999),
      ]) {
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                accountId: item.$1,
                merchant: 'Test',
                amountMinor: item.$3,
                date: item.$2,
              ),
            );
      }
      final report = buildFinanceReport(
        period: ReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 9, 2)),
        allTransactions: await db.select(db.transactions).get(),
        categories: [],
        accountId: 'a',
        categoryId: '',
        scopeLabel: 'Account A · Uncategorized',
        comparePrevious: true,
      );
      expect(report.totalExpenseMinor, 300);
      expect(report.previous!.totalExpenseMinor, 50);
      expect(report.previous!.period.start, DateTime(2026, 8, 30));
      final csv = reportToCsv(report, categoryNameById: {});
      expect(csv, contains('Account A · Uncategorized'));
      expect(csv, contains('Expense,0.50,2.50'));
      expect(
        ReportPeriod.forMonth(DateTime(2026, 1)).previous.start,
        DateTime(2025, 12),
      );
      expect(ReportPeriod.forYear(2026).previous.start, DateTime(2025));
    },
  );

  test(
    'automatic balances honor currency and manual progress is preserved',
    () async {
      final repo = GoalsRepository(db);
      final id = await repo.createGoal(
        title: 'Savings',
        type: 'financial',
        currentValue: 25,
        targetValue: 1000,
      );
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              name: 'Savings',
              type: 'savings',
              balanceMinor: const Value(20000),
            ),
          );
      await repo.addLink(
        goalId: id,
        linkedType: 'account',
        linkedId: account.id,
      );
      await repo.setAutomaticProgress(id, true);
      await repo.updateProgress(id, 999);
      final goal = (await repo.getGoal(id))!;
      expect(goal.currentValue, 25);
      double compute(String currency) => automaticGoalProgress(
        goal: goal,
        links: [
          GoalLink(
            id: 'link',
            goalId: id,
            linkedType: 'account',
            linkedId: account.id,
          ),
        ],
        accounts: [account],
        tasks: [],
        habits: [],
        logs: [],
        currencyCode: currency,
        now: DateTime(2026, 9, 13),
      );
      expect(compute('INR'), 200);
      expect(compute('USD'), 0);
      await repo.setAutomaticProgress(id, false);
      expect((await repo.getGoal(id))!.currentValue, 25);
      await repo.updateProgress(id, 30);
      expect((await repo.getGoal(id))!.currentValue, 30);
    },
  );

  test(
    'automatic habits exclude earlier, future, incomplete and unscheduled logs',
    () async {
      final goal = await db
          .into(db.goals)
          .insertReturning(
            GoalsCompanion.insert(
              title: 'Check-ins',
              type: const Value('habit'),
              createdAt: Value(DateTime(2026, 9, 10)),
            ),
          );
      final habit = await db
          .into(db.habits)
          .insertReturning(
            HabitsCompanion.insert(
              name: 'Read',
              archived: const Value(true),
              createdAt: Value(DateTime(2026, 9, 10)),
            ),
          );
      final logs = [
        for (final day in [9, 10, 11, 14])
          HabitLog(
            id: '$day',
            habitId: habit.id,
            date: DateTime(2026, 9, day),
            completed: day != 11,
          ),
      ];
      expect(
        automaticGoalProgress(
          goal: goal,
          links: [
            GoalLink(
              id: 'l',
              goalId: goal.id,
              linkedType: 'habit',
              linkedId: habit.id,
            ),
          ],
          accounts: [],
          tasks: [],
          habits: [habit],
          logs: logs,
          currencyCode: 'INR',
          now: DateTime(2026, 9, 13),
        ),
        1,
      );
    },
  );

  test('automatic task progress counts linked completed tasks only', () async {
    final goal = await db
        .into(db.goals)
        .insertReturning(GoalsCompanion.insert(title: 'Tasks'));
    final task = await db
        .into(db.tasks)
        .insertReturning(
          TasksCompanion.insert(title: 'One', status: const Value('done')),
        );
    final links = [
      GoalLink(id: 'l', goalId: goal.id, linkedType: 'task', linkedId: task.id),
    ];
    double compute(List<Task> tasks) => automaticGoalProgress(
      goal: goal,
      links: links,
      accounts: [],
      tasks: tasks,
      habits: [],
      logs: [],
      currencyCode: 'INR',
      now: DateTime.now(),
    );
    expect(compute([task]), 1);
    expect(compute([task.copyWith(status: 'open')]), 0);
    expect(compute([]), 0);
  });

  test('reminder status parses dated habit keys and rejects other payloads', () {
    final reminder = QueuedReminder.fromPayload(
      'lifeos.schedule:habit:h:2026-09-13T00:00:00.000:2026-09-13T09:00:00.000:notification',
      'Read',
    );
    expect(reminder!.time, DateTime(2026, 9, 13, 9));
    expect(QueuedReminder.fromPayload('unrelated', 'Other'), isNull);
    expect(QueuedReminder.fromPayload(null, null), isNull);
  });

  test('v15 goal migration preserves manual progress', () async {
    await db.close();
    db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute(
            'CREATE TABLE goals (id TEXT PRIMARY KEY, title TEXT NOT NULL, current_value REAL NOT NULL)',
          );
          sqlite.execute("INSERT INTO goals VALUES ('g', 'Keep goal', 25)");
          sqlite.execute('CREATE TABLE habits (id TEXT PRIMARY KEY)');
          sqlite.execute(
            'CREATE TABLE habit_logs (id TEXT PRIMARY KEY, habit_id TEXT)',
          );
          sqlite.execute('PRAGMA user_version = 15');
        },
      ),
    );
    final row = await db
        .customSelect('SELECT current_value, progress_mode FROM goals')
        .getSingle();
    expect(row.read<double>('current_value'), 25);
    expect(row.readNullable<String>('progress_mode'), isNull);
  });
}
