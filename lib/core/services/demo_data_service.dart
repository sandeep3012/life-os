import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/app_database_provider.dart';

const _demoPrefix = 'demo-';

class DemoDataSummary {
  const DemoDataSummary({
    required this.transactions,
    required this.habitLogs,
    required this.tasks,
    required this.events,
  });

  final int transactions;
  final int habitLogs;
  final int tasks;
  final int events;
}

/// Creates a deterministic, removable dataset for exploring the app in debug
/// builds. Every owned row uses [_demoPrefix], while shared user categories
/// are reused by name and are never removed.
class DemoDataService {
  DemoDataService(this._db);

  final AppDatabase _db;

  Future<bool> get hasDemoData async {
    final row = await (_db.select(_db.accounts)
          ..where((account) => account.id.like('$_demoPrefix%'))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<DemoDataSummary> generate({int months = 24}) async {
    if (await hasDemoData) {
      throw StateError('Demo data already exists. Remove it before generating again.');
    }

    final random = Random(20260829);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final firstMonth = DateTime(currentMonth.year, currentMonth.month - months + 1);

    var transactionCount = 0;
    var habitLogCount = 0;
    var taskCount = 0;
    var eventCount = 0;

    await _db.transaction(() async {
      final categoryIds = await _ensureCategories();
      final accountIds = await _insertAccounts(now);

      final transactions = <TransactionsCompanion>[];
      final budgets = <BudgetsCompanion>[];
      for (var monthIndex = 0; monthIndex < months; monthIndex++) {
        final month = DateTime(firstMonth.year, firstMonth.month + monthIndex);
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

        void addTransaction({
          required String account,
          required String category,
          required String merchant,
          required int amountMinor,
          required int day,
          String? note,
          String paymentMode = 'upi',
        }) {
          final safeDay = min(day, daysInMonth);
          final id = '$_demoPrefix transaction-${month.year}-${month.month}-$transactionCount'
              .replaceAll(' ', '');
          transactions.add(
            TransactionsCompanion.insert(
              id: Value(id),
              accountId: accountIds[account]!,
              categoryId: Value(categoryIds[category]),
              merchant: merchant,
              amountMinor: amountMinor,
              date: DateTime(month.year, month.month, safeDay, 12),
              note: Value(note),
              paymentMode: Value(paymentMode),
              createdAt: Value(DateTime(month.year, month.month, safeDay, 12)),
            ),
          );
          transactionCount++;
        }

        addTransaction(
          account: 'checking',
          category: 'Income',
          merchant: 'Monthly salary',
          amountMinor: 9500000,
          day: 1,
          note: 'Demo salary credit',
          paymentMode: 'net_banking',
        );
        addTransaction(
          account: 'checking',
          category: 'Rent',
          merchant: 'Apartment rent',
          amountMinor: -2200000,
          day: 3,
          paymentMode: 'net_banking',
        );
        addTransaction(
          account: 'credit',
          category: 'Subscriptions',
          merchant: 'Streaming bundle',
          amountMinor: -79900,
          day: 8,
          paymentMode: 'card',
        );
        addTransaction(
          account: 'checking',
          category: 'Subscriptions',
          merchant: 'Mobile and internet',
          amountMinor: -(149900 + random.nextInt(25000)),
          day: 12,
        );

        for (var i = 0; i < 8; i++) {
          const groceryMerchants = ['Fresh Market', 'Daily Basket', 'Supermart'];
          addTransaction(
            account: i.isEven ? 'checking' : 'credit',
            category: 'Groceries',
            merchant: groceryMerchants[random.nextInt(groceryMerchants.length)],
            amountMinor: -(55000 + random.nextInt(180000)),
            day: 2 + random.nextInt(max(1, daysInMonth - 2)),
            paymentMode: i.isEven ? 'upi' : 'card',
          );
        }
        for (var i = 0; i < 7; i++) {
          const diningMerchants = ['Cafe Corner', 'Spice Kitchen', 'Office Lunch', 'Weekend Dinner'];
          addTransaction(
            account: i == 0 ? 'cash' : 'credit',
            category: 'Dining',
            merchant: diningMerchants[random.nextInt(diningMerchants.length)],
            amountMinor: -(25000 + random.nextInt(125000)),
            day: 1 + random.nextInt(daysInMonth),
            paymentMode: i == 0 ? 'cash' : 'card',
          );
        }
        for (var i = 0; i < 5; i++) {
          const transportMerchants = ['Metro card', 'Fuel station', 'Cab ride', 'Bus pass'];
          addTransaction(
            account: 'checking',
            category: 'Transport',
            merchant: transportMerchants[random.nextInt(transportMerchants.length)],
            amountMinor: -(3000 + random.nextInt(145000)),
            day: 1 + random.nextInt(daysInMonth),
          );
        }
        for (var i = 0; i < 2; i++) {
          addTransaction(
            account: 'credit',
            category: 'Entertainment',
            merchant: i == 0 ? 'Cinema' : 'Weekend activity',
            amountMinor: -(40000 + random.nextInt(180000)),
            day: 1 + random.nextInt(daysInMonth),
            paymentMode: 'card',
          );
        }

        if (monthIndex % 3 == 0) {
          const limits = {
            'Groceries': 850000,
            'Dining': 550000,
            'Transport': 450000,
            'Entertainment': 350000,
            'Subscriptions': 300000,
          };
          for (final entry in limits.entries) {
            budgets.add(
              BudgetsCompanion.insert(
                id: Value(
                  '$_demoPrefix budget-${entry.key.toLowerCase()}-${month.year}-${month.month}'
                      .replaceAll(' ', '-'),
                ),
                categoryId: categoryIds[entry.key]!,
                limitMinor: entry.value + random.nextInt(75000),
                startDate: month,
                effectiveMonth: Value(month),
                createdAt: Value(month),
              ),
            );
          }
        }
      }
      await _db.batch((batch) {
        batch.insertAll(_db.transactions, transactions);
        batch.insertAll(_db.budgets, budgets);
        batch.insertAll(_db.recurringTransactions, [
          RecurringTransactionsCompanion.insert(
            id: const Value('${_demoPrefix}recurring-salary'),
            accountId: accountIds['checking']!,
            categoryId: Value(categoryIds['Income']),
            merchant: 'Monthly salary',
            amountMinor: 9500000,
            frequency: const Value('monthly'),
            nextDueDate: DateTime(currentMonth.year, currentMonth.month + 1, 1),
            paymentMode: const Value('net_banking'),
          ),
          RecurringTransactionsCompanion.insert(
            id: const Value('${_demoPrefix}recurring-rent'),
            accountId: accountIds['checking']!,
            categoryId: Value(categoryIds['Rent']),
            merchant: 'Apartment rent',
            amountMinor: -2200000,
            frequency: const Value('monthly'),
            nextDueDate: DateTime(currentMonth.year, currentMonth.month + 1, 3),
            paymentMode: const Value('net_banking'),
          ),
          RecurringTransactionsCompanion.insert(
            id: const Value('${_demoPrefix}recurring-streaming'),
            accountId: accountIds['credit']!,
            categoryId: Value(categoryIds['Subscriptions']),
            merchant: 'Streaming bundle',
            amountMinor: -79900,
            frequency: const Value('monthly'),
            nextDueDate: DateTime(currentMonth.year, currentMonth.month + 1, 8),
            paymentMode: const Value('card'),
          ),
        ]);
        batch.insertAll(_db.bills, [
          BillsCompanion.insert(
            id: const Value('${_demoPrefix}bill-electricity'),
            name: 'Electricity bill',
            accountId: Value(accountIds['checking']),
            categoryId: Value(categoryIds['Subscriptions']),
            amountMinor: 285000,
            dueDate: DateTime(currentMonth.year, currentMonth.month + 1, 6),
          ),
          BillsCompanion.insert(
            id: const Value('${_demoPrefix}bill-credit-card'),
            name: 'Credit card payment',
            accountId: Value(accountIds['checking']),
            amountMinor: 1285000,
            dueDate: DateTime(currentMonth.year, currentMonth.month + 1, 12),
          ),
          BillsCompanion.insert(
            id: const Value('${_demoPrefix}bill-insurance'),
            name: 'Health insurance renewal',
            accountId: Value(accountIds['savings']),
            amountMinor: 2400000,
            dueDate: DateTime(currentMonth.year, currentMonth.month + 3, 20),
            frequency: const Value('yearly'),
          ),
        ]);
      });

      final habitIds = await _insertHabits(firstMonth);
      final logs = <HabitLogsCompanion>[];
      final totalDays = now.difference(firstMonth).inDays + 1;
      final probabilities = <String, double>{
        'exercise': .68,
        'water': .86,
        'reading': .72,
        'meditation': .61,
        'sleep': .76,
      };
      for (var dayOffset = 0; dayOffset < totalDays; dayOffset++) {
        final day = DateTime(firstMonth.year, firstMonth.month, firstMonth.day + dayOffset);
        for (final entry in habitIds.entries) {
          if (random.nextDouble() <= probabilities[entry.key]!) {
            logs.add(
              HabitLogsCompanion.insert(
                id: Value('$_demoPrefix habit-log-${entry.key}-$dayOffset'),
                habitId: entry.value,
                date: day,
                notes: dayOffset % 47 == 0 ? const Value('Felt good today') : const Value.absent(),
              ),
            );
            habitLogCount++;
          }
        }
      }
      await _db.batch((batch) => batch.insertAll(_db.habitLogs, logs));

      final tasks = <TasksCompanion>[];
      const taskTitles = [
        'Review monthly budget',
        'Plan weekly meals',
        'Book health checkup',
        'Call family',
        'Organise documents',
        'Prepare project update',
        'Buy household supplies',
        'Review personal goals',
      ];
      for (var monthIndex = 0; monthIndex < months; monthIndex++) {
        final month = DateTime(firstMonth.year, firstMonth.month + monthIndex);
        for (var i = 0; i < taskTitles.length; i++) {
          final due = DateTime(month.year, month.month, min(3 + i * 3, 27), 18);
          final isPast = due.isBefore(now.subtract(const Duration(days: 2)));
          final done = isPast && random.nextDouble() < .84;
          tasks.add(
            TasksCompanion.insert(
              id: Value('$_demoPrefix task-$monthIndex-$i'),
              title: taskTitles[i],
              description: Value('Demo task for ${month.month}/${month.year}'),
              dueDate: Value(due),
              priority: Value(i % 4 == 0 ? 'high' : i % 3 == 0 ? 'low' : 'medium'),
              status: Value(done ? 'done' : 'open'),
              reminderEnabled: const Value(false),
              createdAt: Value(due.subtract(const Duration(days: 5))),
              completedAt: Value(done ? due.subtract(const Duration(hours: 2)) : null),
            ),
          );
          taskCount++;
        }
      }
      await _db.batch((batch) => batch.insertAll(_db.tasks, tasks));
      await _db.batch((batch) {
        batch.insertAll(_db.subtasks, [
          SubtasksCompanion.insert(
            id: const Value('${_demoPrefix}subtask-budget-1'),
            taskId: '${_demoPrefix}task-${months - 1}-0',
            title: 'Check category totals',
            done: const Value(true),
          ),
          SubtasksCompanion.insert(
            id: const Value('${_demoPrefix}subtask-budget-2'),
            taskId: '${_demoPrefix}task-${months - 1}-0',
            title: 'Adjust next month limits',
          ),
          SubtasksCompanion.insert(
            id: const Value('${_demoPrefix}subtask-meals-1'),
            taskId: '${_demoPrefix}task-${months - 1}-1',
            title: 'Choose five dinners',
            done: const Value(true),
          ),
          SubtasksCompanion.insert(
            id: const Value('${_demoPrefix}subtask-meals-2'),
            taskId: '${_demoPrefix}task-${months - 1}-1',
            title: 'Prepare grocery list',
          ),
        ]);
      });

      await _insertGoalsAndMilestones(now, accountIds, habitIds);

      final events = <EventsCompanion>[];
      for (var monthIndex = 0; monthIndex < months; monthIndex++) {
        final month = DateTime(firstMonth.year, firstMonth.month + monthIndex);
        final monthEvents = [
          ('Monthly planning', 2, 9),
          ('Budget review', 10, 19),
          ('Family catch-up', 17, 18),
          ('Personal review', 25, 10),
        ];
        for (var i = 0; i < monthEvents.length; i++) {
          final item = monthEvents[i];
          final start = DateTime(month.year, month.month, item.$2, item.$3);
          events.add(
            EventsCompanion.insert(
              id: Value('$_demoPrefix event-$monthIndex-$i'),
              title: item.$1,
              startTime: start,
              endTime: Value(start.add(const Duration(hours: 1))),
              createdAt: Value(start.subtract(const Duration(days: 7))),
            ),
          );
          eventCount++;
        }
      }
      await _db.batch((batch) => batch.insertAll(_db.events, events));
      await _insertNotes(now);
    });

    return DemoDataSummary(
      transactions: transactionCount,
      habitLogs: habitLogCount,
      tasks: taskCount,
      events: eventCount,
    );
  }

  Future<void> remove() async {
    await _db.transaction(() async {
      // Children and polymorphic links must go before their parent records.
      await (_db.delete(_db.entityTags)..where(
            (row) => row.entityId.like('$_demoPrefix%'),
          ))
          .go();
      await (_db.delete(_db.goalMilestones)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.goalLinks)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.subtasks)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.habitLogs)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.transactions)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.budgets)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.recurringTransactions)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.bills)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.events)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.notes)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.tasks)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.goals)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.habits)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.accounts)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
      await (_db.delete(_db.categories)
            ..where((row) => row.id.like('$_demoPrefix%')))
          .go();
    });
  }

  Future<Map<String, String>> _ensureCategories() async {
    const definitions = {
      'Dining': ('restaurant', '#E0475A', 'expense'),
      'Groceries': ('shopping_cart', '#2E9E63', 'expense'),
      'Transport': ('directions_car', '#2F6FED', 'expense'),
      'Rent': ('home', '#A67C00', 'expense'),
      'Entertainment': ('movie', '#A63FBE', 'expense'),
      'Subscriptions': ('autorenew', '#7C5CE7', 'expense'),
      'Income': ('payments', '#1E8F5E', 'income'),
    };
    final existing = await _db.select(_db.categories).get();
    final result = <String, String>{};
    for (final entry in definitions.entries) {
      final match = existing.where((row) => row.name.toLowerCase() == entry.key.toLowerCase()).firstOrNull;
      if (match != null) {
        result[entry.key] = match.id;
      } else {
        final id = '$_demoPrefix category-${entry.key.toLowerCase()}'.replaceAll(' ', '-');
        await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: Value(id),
            name: entry.key,
            icon: Value(entry.value.$1),
            colorHex: entry.value.$2,
            kind: Value(entry.value.$3),
          ),
        );
        result[entry.key] = id;
      }
    }
    return result;
  }

  Future<Map<String, String>> _insertAccounts(DateTime now) async {
    const ids = {
      'checking': '${_demoPrefix}account-checking',
      'savings': '${_demoPrefix}account-savings',
      'credit': '${_demoPrefix}account-credit',
      'cash': '${_demoPrefix}account-cash',
    };
    await _db.batch((batch) {
      batch.insertAll(_db.accounts, [
        AccountsCompanion.insert(id: const Value('${_demoPrefix}account-checking'), name: 'Demo Checking', type: 'Checking', balanceMinor: const Value(2450000), createdAt: Value(DateTime(now.year - 2, now.month)), updatedAt: Value(now)),
        AccountsCompanion.insert(id: const Value('${_demoPrefix}account-savings'), name: 'Emergency Savings', type: 'Savings', balanceMinor: const Value(8650000), createdAt: Value(DateTime(now.year - 2, now.month)), updatedAt: Value(now)),
        AccountsCompanion.insert(id: const Value('${_demoPrefix}account-credit'), name: 'Rewards Card', type: 'Credit Card', balanceMinor: const Value(-1285000), createdAt: Value(DateTime(now.year - 2, now.month)), updatedAt: Value(now)),
        AccountsCompanion.insert(id: const Value('${_demoPrefix}account-cash'), name: 'Cash Wallet', type: 'Cash', balanceMinor: const Value(185000), createdAt: Value(DateTime(now.year - 2, now.month)), updatedAt: Value(now)),
      ]);
    });
    return ids;
  }

  Future<Map<String, String>> _insertHabits(DateTime firstMonth) async {
    const ids = {
      'exercise': '${_demoPrefix}habit-exercise',
      'water': '${_demoPrefix}habit-water',
      'reading': '${_demoPrefix}habit-reading',
      'meditation': '${_demoPrefix}habit-meditation',
      'sleep': '${_demoPrefix}habit-sleep',
    };
    await _db.batch((batch) {
      batch.insertAll(_db.habits, [
        HabitsCompanion.insert(id: const Value('${_demoPrefix}habit-exercise'), name: 'Morning workout', frequency: const Value('custom'), targetPerWeek: const Value(5), createdAt: Value(firstMonth)),
        HabitsCompanion.insert(id: const Value('${_demoPrefix}habit-water'), name: 'Drink 8 glasses of water', createdAt: Value(firstMonth)),
        HabitsCompanion.insert(id: const Value('${_demoPrefix}habit-reading'), name: 'Read for 20 minutes', frequency: const Value('custom'), targetPerWeek: const Value(5), createdAt: Value(firstMonth)),
        HabitsCompanion.insert(id: const Value('${_demoPrefix}habit-meditation'), name: 'Meditate', frequency: const Value('custom'), targetPerWeek: const Value(4), createdAt: Value(firstMonth)),
        HabitsCompanion.insert(id: const Value('${_demoPrefix}habit-sleep'), name: 'Sleep before 11 PM', createdAt: Value(firstMonth)),
        HabitsCompanion.insert(id: const Value('${_demoPrefix}habit-journal-archived'), name: 'Evening journal', archived: const Value(true), createdAt: Value(firstMonth)),
      ]);
    });
    return ids;
  }

  Future<void> _insertGoalsAndMilestones(
    DateTime now,
    Map<String, String> accountIds,
    Map<String, String> habitIds,
  ) async {
    final goals = [
      GoalsCompanion.insert(id: const Value('${_demoPrefix}goal-emergency'), title: 'Build emergency fund', description: const Value('Save six months of essential expenses'), type: const Value('financial'), targetDate: Value(DateTime(now.year + 1, 3, 31)), targetValue: const Value(1200000.0), currentValue: const Value(865000.0), createdAt: Value(DateTime(now.year - 1, 1, 10))),
      GoalsCompanion.insert(id: const Value('${_demoPrefix}goal-fitness'), title: 'Complete 200 workouts', type: const Value('habit'), targetDate: Value(DateTime(now.year, 12, 31)), targetValue: const Value(200.0), currentValue: const Value(137.0), createdAt: Value(DateTime(now.year, 1, 1))),
      GoalsCompanion.insert(id: const Value('${_demoPrefix}goal-reading'), title: 'Read 24 books', type: const Value('generic'), targetDate: Value(DateTime(now.year, 12, 31)), targetValue: const Value(24.0), currentValue: const Value(16.0), createdAt: Value(DateTime(now.year, 1, 1))),
      GoalsCompanion.insert(id: const Value('${_demoPrefix}goal-trip'), title: 'Plan a family trip', type: const Value('generic'), targetDate: Value(DateTime(now.year + 1, 1, 15)), targetValue: const Value(100.0), currentValue: const Value(45.0), createdAt: Value(DateTime(now.year, 4, 1))),
      GoalsCompanion.insert(id: const Value('${_demoPrefix}goal-course'), title: 'Finish professional course', type: const Value('generic'), status: const Value('completed'), targetValue: const Value(12.0), currentValue: const Value(12.0), createdAt: Value(DateTime(now.year - 1, 6, 1))),
    ];
    await _db.batch((batch) {
      batch.insertAll(_db.goals, goals);
      batch.insertAll(_db.goalLinks, [
        GoalLinksCompanion.insert(id: const Value('${_demoPrefix}goal-link-emergency'), goalId: '${_demoPrefix}goal-emergency', linkedType: 'account', linkedId: accountIds['savings']!),
        GoalLinksCompanion.insert(id: const Value('${_demoPrefix}goal-link-fitness'), goalId: '${_demoPrefix}goal-fitness', linkedType: 'habit', linkedId: habitIds['exercise']!),
        GoalLinksCompanion.insert(id: const Value('${_demoPrefix}goal-link-reading'), goalId: '${_demoPrefix}goal-reading', linkedType: 'habit', linkedId: habitIds['reading']!),
      ]);
      batch.insertAll(_db.goalMilestones, [
        GoalMilestonesCompanion.insert(id: const Value('${_demoPrefix}milestone-emergency-1'), goalId: '${_demoPrefix}goal-emergency', title: 'Save first ₹3 lakh', completed: const Value(true), sortOrder: const Value(0)),
        GoalMilestonesCompanion.insert(id: const Value('${_demoPrefix}milestone-emergency-2'), goalId: '${_demoPrefix}goal-emergency', title: 'Reach ₹6 lakh', completed: const Value(true), sortOrder: const Value(1)),
        GoalMilestonesCompanion.insert(id: const Value('${_demoPrefix}milestone-emergency-3'), goalId: '${_demoPrefix}goal-emergency', title: 'Reach final target', sortOrder: const Value(2)),
        GoalMilestonesCompanion.insert(id: const Value('${_demoPrefix}milestone-trip-1'), goalId: '${_demoPrefix}goal-trip', title: 'Choose destination', completed: const Value(true), sortOrder: const Value(0)),
        GoalMilestonesCompanion.insert(id: const Value('${_demoPrefix}milestone-trip-2'), goalId: '${_demoPrefix}goal-trip', title: 'Book travel and hotel', sortOrder: const Value(1)),
      ]);
    });
  }

  Future<void> _insertNotes(DateTime now) async {
    const content = [
      ('Annual priorities', 'Health, family, focused work, and financial resilience.'),
      ('Books to read', 'A mix of biographies, design, psychology, and personal finance.'),
      ('Meal ideas', 'Vegetable pulao, lentil soup, grilled paneer, overnight oats.'),
      ('Travel checklist', 'Tickets, accommodation, documents, medicine, chargers.'),
      ('Monthly reflection', 'What went well, what felt difficult, and what to change.'),
      ('Gift ideas', 'Keep a running list for family and close friends.'),
      ('Home improvements', 'Better lighting, storage shelves, and desk organisation.'),
      ('Learning plan', 'Two focused sessions each week and one monthly project.'),
      ('Emergency contacts', 'Maintain an offline list of essential contacts.'),
      ('Ideas inbox', 'A place to capture ideas before organising them.'),
    ];
    await _db.batch((batch) {
      batch.insertAll(_db.notes, [
        for (var i = 0; i < content.length; i++)
          NotesCompanion.insert(
            id: Value('$_demoPrefix note-$i'.replaceAll(' ', '')),
            title: content[i].$1,
            body: Value(content[i].$2),
            createdAt: Value(now.subtract(Duration(days: 25 * (i + 1)))),
            updatedAt: Value(now.subtract(Duration(days: 7 * i))),
          ),
      ]);
    });
  }
}

final demoDataServiceProvider = Provider<DemoDataService>(
  (ref) => DemoDataService(ref.watch(appDatabaseProvider)),
);
