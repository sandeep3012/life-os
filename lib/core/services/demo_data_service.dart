import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../scheduling/repeat_schedule.dart';
import '../utils/date_utils.dart';

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
    final row =
        await (_db.select(_db.accounts)
              ..where((account) => account.id.like('$_demoPrefix%'))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Older cleanup matched child IDs only. Manual check-ins on demo habits
  /// have UUIDs, and could survive after their parent demo habit was removed.
  Future<bool> get _hasOrphanedDemoRows async {
    final row = await _db.customSelect(
      '''
            SELECT 1 WHERE EXISTS (SELECT 1 FROM habit_logs WHERE id LIKE ? OR habit_id LIKE ?)
              OR EXISTS (SELECT 1 FROM habits WHERE id LIKE ?)
              OR EXISTS (SELECT 1 FROM tasks WHERE id LIKE ?)
              OR EXISTS (SELECT 1 FROM events WHERE id LIKE ?)
              OR EXISTS (SELECT 1 FROM transactions WHERE id LIKE ?)
              OR EXISTS (SELECT 1 FROM medications WHERE id LIKE ?)
              OR EXISTS (SELECT 1 FROM learn_books WHERE id LIKE ?)
          ''',
      variables: List.generate(8, (_) => Variable<String>('$_demoPrefix%')),
    ).getSingleOrNull();
    return row != null;
  }

  Future<DemoDataSummary> generate({int months = 24}) async {
    if (months < 1) {
      throw ArgumentError.value(months, 'months', 'Must be at least 1');
    }
    final random = Random(20260829);
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final firstMonth = DateTime(
      currentMonth.year,
      currentMonth.month - months + 1,
    );

    var transactionCount = 0;
    var habitLogCount = 0;
    var taskCount = 0;
    var eventCount = 0;

    await _db.transaction(() async {
      if (await hasDemoData) {
        throw StateError(
          'Demo data already exists. Remove it before generating again.',
        );
      }
      // Recovery and insertion are atomic: a failed generation must not
      // leave cleanup partially applied.
      if (await _hasOrphanedDemoRows) {
        await remove();
      }
      final categoryIds = await _ensureCategories();
      await _insertAccountTypes(now);
      final accountIds = await _insertAccounts(now);
      // Folders and documents come first: a transaction's receipt is a
      // foreign key into Documents, so the rows have to exist by then.
      final folderIds = await _insertFolders(now);
      final documentIds = await _insertDocuments(now, folderIds);

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
          final id =
              '$_demoPrefix transaction-${month.year}-${month.month}-$transactionCount'
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
          const groceryMerchants = [
            'Fresh Market',
            'Daily Basket',
            'Supermart',
          ];
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
          const diningMerchants = [
            'Cafe Corner',
            'Spice Kitchen',
            'Office Lunch',
            'Weekend Dinner',
          ];
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
          const transportMerchants = [
            'Metro card',
            'Fuel station',
            'Cab ride',
            'Bus pass',
          ];
          addTransaction(
            account: 'checking',
            category: 'Transport',
            merchant:
                transportMerchants[random.nextInt(transportMerchants.length)],
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

      transactionCount += await _insertFinanceEdgeCases(
        now,
        accountIds,
        categoryIds,
        documentIds,
      );

      final habitIds = await _insertHabits(firstMonth);
      final logs = <HabitLogsCompanion>[];
      final loggedDays = <String>{};
      final totalDays = now.difference(firstMonth).inDays + 1;
      final probabilities = <String, double>{
        'exercise': .68,
        'water': .86,
        'reading': .72,
        'meditation': .61,
        'sleep': .76,
      };
      for (var dayOffset = 0; dayOffset < totalDays; dayOffset++) {
        final day = dateOnly(
          DateTime(
            firstMonth.year,
            firstMonth.month,
            firstMonth.day + dayOffset,
          ),
        );
        for (final entry in habitIds.entries) {
          if (random.nextDouble() <= probabilities[entry.key]!) {
            // HabitLogs enforces one record per habit per local calendar day.
            // The set makes generation robust against locale/DST date
            // normalization and future changes to the date-range loop.
            final key = '${entry.value}:${day.toIso8601String()}';
            if (!loggedDays.add(key)) continue;
            logs.add(
              HabitLogsCompanion.insert(
                id: Value('$_demoPrefix habit-log-${entry.key}-$dayOffset'),
                habitId: entry.value,
                date: day,
                notes: dayOffset % 47 == 0
                    ? const Value('Felt good today')
                    : const Value.absent(),
              ),
            );
            habitLogCount++;
          }
        }
      }
      await _db.batch((batch) => batch.insertAll(_db.habitLogs, logs));
      habitLogCount += await _insertHabitEdgeCases(now, categoryIds);

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
              // Subtasks reference this exact ID; whitespace breaks the FK.
              id: Value('${_demoPrefix}task-$monthIndex-$i'),
              title: taskTitles[i],
              description: Value('Demo task for ${month.month}/${month.year}'),
              dueDate: Value(due),
              priority: Value(
                i % 4 == 0
                    ? 'high'
                    : i % 3 == 0
                    ? 'low'
                    : 'medium',
              ),
              status: Value(done ? 'done' : 'open'),
              reminderEnabled: const Value(false),
              createdAt: Value(due.subtract(const Duration(days: 5))),
              completedAt: Value(
                done ? due.subtract(const Duration(hours: 2)) : null,
              ),
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

      taskCount += await _insertTaskEdgeCases(now, categoryIds);

      await _insertGoalsAndMilestones(now, accountIds, habitIds);
      await _insertGoalEdgeCases(now, accountIds, habitIds);

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
      eventCount += await _insertEventEdgeCases(now);
      await _insertNotes(now, folderIds);
      await _insertHealthData(now);
      await _insertLearnData(now);
      await _insertTags(now, documentIds);
      await _insertDismissedInsights(now);
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
            (row) =>
                row.entityId.like('$_demoPrefix%') |
                row.tagId.like('$_demoPrefix%'),
          ))
          .go();
      await (_db.delete(
        _db.goalMilestones,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.goalLinks,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.subtasks,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(_db.habitLogs)..where(
            (row) =>
                row.id.like('$_demoPrefix%') |
                row.habitId.like('$_demoPrefix%'),
          ))
          .go();
      await (_db.delete(
        _db.transactions,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.budgets,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.recurringTransactions,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.bills,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.events,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.notes,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.tasks,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.goals,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.habits,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      // Documents are referenced by transactions (receipts), so they can
      // only go once those are gone; folders own both notes and documents.
      await (_db.delete(
        _db.documents,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      // Child folders first: a single DELETE covering both a parent and its
      // child gives no ordering guarantee, and the parent going first would
      // trip the self-referential foreign key.
      await (_db.delete(_db.folders)..where(
            (row) =>
                row.id.like('$_demoPrefix%') & row.parentFolderId.isNotNull(),
          ))
          .go();
      await (_db.delete(
        _db.folders,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.tags,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.insights,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.accounts,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.accountTypes,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.categories,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      // Health
      await (_db.delete(
        _db.exerciseSetLogs,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.workoutLogs,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.exercises,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.workoutDays,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.medicationLogs,
      )..where(
        (row) =>
            row.id.like('$_demoPrefix%') |
            row.medicationId.like('$_demoPrefix%'),
      )).go();
      await (_db.delete(
        _db.medications,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      // Learn
      await (_db.delete(
        _db.learnNotes,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
      await (_db.delete(
        _db.learnBooks,
      )..where((row) => row.id.like('$_demoPrefix%'))).go();
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
      // Habit-kind categories: the habits screen filters on kind == 'habit',
      // so the expense set above never reaches its picker.
      'Wellness': ('spa', '#3FA6A0', 'habit'),
      'Fitness': ('fitness_center', '#C2703D', 'habit'),
      'Learning': ('school', '#7C6BC4', 'habit'),
    };
    final existing = await _db.select(_db.categories).get();
    final result = <String, String>{};
    for (final entry in definitions.entries) {
      final match = existing
          .where((row) => row.name.toLowerCase() == entry.key.toLowerCase())
          .firstOrNull;
      if (match != null) {
        result[entry.key] = match.id;
      } else {
        final id = '$_demoPrefix category-${entry.key.toLowerCase()}'
            .replaceAll(' ', '-');
        await _db
            .into(_db.categories)
            .insert(
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

  /// Account kinds beyond the app's lazily-seeded defaults, so the type
  /// picker has user-created rows in it too.
  Future<void> _insertAccountTypes(DateTime now) async {
    await _db.batch((batch) {
      batch.insertAll(_db.accountTypes, [
        AccountTypesCompanion.insert(
          id: const Value('${_demoPrefix}acct-type-brokerage'),
          name: 'Brokerage',
          icon: const Value('trending_up'),
          createdAt: Value(now),
        ),
        AccountTypesCompanion.insert(
          id: const Value('${_demoPrefix}acct-type-loan'),
          name: 'Loan',
          icon: const Value('account_balance'),
          createdAt: Value(now),
        ),
        AccountTypesCompanion.insert(
          id: const Value('${_demoPrefix}acct-type-wallet'),
          name: 'Digital Wallet',
          icon: const Value('wallet'),
          createdAt: Value(now),
        ),
      ]);
    });
  }

  Future<Map<String, String>> _insertAccounts(DateTime now) async {
    const ids = {
      'checking': '${_demoPrefix}account-checking',
      'savings': '${_demoPrefix}account-savings',
      'credit': '${_demoPrefix}account-credit',
      'cash': '${_demoPrefix}account-cash',
      'brokerage': '${_demoPrefix}account-brokerage',
      'loan': '${_demoPrefix}account-loan',
      'wallet': '${_demoPrefix}account-wallet',
      'closed': '${_demoPrefix}account-closed',
      'foreign': '${_demoPrefix}account-foreign',
    };
    await _db.batch((batch) {
      batch.insertAll(_db.accounts, [
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-checking'),
          name: 'Demo Checking',
          type: 'Checking',
          balanceMinor: const Value(2450000),
          createdAt: Value(DateTime(now.year - 2, now.month)),
          updatedAt: Value(now),
        ),
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-savings'),
          name: 'Emergency Savings',
          type: 'Savings',
          balanceMinor: const Value(8650000),
          createdAt: Value(DateTime(now.year - 2, now.month)),
          updatedAt: Value(now),
        ),
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-credit'),
          name: 'Rewards Card',
          type: 'Credit Card',
          balanceMinor: const Value(-1285000),
          createdAt: Value(DateTime(now.year - 2, now.month)),
          updatedAt: Value(now),
        ),
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-cash'),
          name: 'Cash Wallet',
          type: 'Cash',
          balanceMinor: const Value(185000),
          createdAt: Value(DateTime(now.year - 2, now.month)),
          updatedAt: Value(now),
        ),
        // Large positive balance — exercises lakh/crore formatting.
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-brokerage'),
          name: 'Brokerage Portfolio',
          type: 'Brokerage',
          balanceMinor: const Value(154275000),
          createdAt: Value(DateTime(now.year - 3, now.month)),
          updatedAt: Value(now),
        ),
        // Large negative balance — a liability, not a credit-card float.
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-loan'),
          name: 'Home Loan',
          type: 'Loan',
          balanceMinor: const Value(-487500000),
          createdAt: Value(DateTime(now.year - 3, now.month)),
          updatedAt: Value(now),
        ),
        // Exactly zero — the "empty account" rendering.
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-wallet'),
          name: 'UPI Wallet',
          type: 'Digital Wallet',
          balanceMinor: const Value(0),
          createdAt: Value(DateTime(now.year, now.month - 3)),
          updatedAt: Value(now),
        ),
        // Deactivated: must drop out of totals and pickers but keep history.
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-closed'),
          name: 'Old Salary Account (closed)',
          type: 'Checking',
          balanceMinor: const Value(0),
          isActive: const Value(false),
          createdAt: Value(DateTime(now.year - 3, now.month)),
          updatedAt: Value(now),
        ),
        // Non-default currency — checks nothing assumes INR.
        AccountsCompanion.insert(
          id: const Value('${_demoPrefix}account-foreign'),
          name: 'USD Travel Card',
          type: 'Savings',
          balanceMinor: const Value(120000),
          currencyCode: const Value('USD'),
          createdAt: Value(DateTime(now.year - 1, now.month)),
          updatedAt: Value(now),
        ),
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
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-exercise'),
          name: 'Morning workout',
          frequency: const Value('custom'),
          targetPerWeek: const Value(5),
          createdAt: Value(firstMonth),
        ),
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-water'),
          name: 'Drink 8 glasses of water',
          createdAt: Value(firstMonth),
        ),
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-reading'),
          name: 'Read for 20 minutes',
          frequency: const Value('custom'),
          targetPerWeek: const Value(5),
          createdAt: Value(firstMonth),
        ),
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-meditation'),
          name: 'Meditate',
          frequency: const Value('custom'),
          targetPerWeek: const Value(4),
          createdAt: Value(firstMonth),
        ),
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-sleep'),
          name: 'Sleep before 11 PM',
          createdAt: Value(firstMonth),
        ),
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-journal-archived'),
          name: 'Evening journal',
          archived: const Value(true),
          createdAt: Value(firstMonth),
        ),
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
      GoalsCompanion.insert(
        id: const Value('${_demoPrefix}goal-emergency'),
        title: 'Build emergency fund',
        description: const Value('Save six months of essential expenses'),
        type: const Value('financial'),
        targetDate: Value(DateTime(now.year + 1, 3, 31)),
        targetValue: const Value(1200000.0),
        currentValue: const Value(865000.0),
        createdAt: Value(DateTime(now.year - 1, 1, 10)),
      ),
      GoalsCompanion.insert(
        id: const Value('${_demoPrefix}goal-fitness'),
        title: 'Complete 200 workouts',
        type: const Value('habit'),
        targetDate: Value(DateTime(now.year, 12, 31)),
        targetValue: const Value(200.0),
        currentValue: const Value(137.0),
        createdAt: Value(DateTime(now.year, 1, 1)),
      ),
      GoalsCompanion.insert(
        id: const Value('${_demoPrefix}goal-reading'),
        title: 'Read 24 books',
        type: const Value('generic'),
        targetDate: Value(DateTime(now.year, 12, 31)),
        targetValue: const Value(24.0),
        currentValue: const Value(16.0),
        createdAt: Value(DateTime(now.year, 1, 1)),
      ),
      GoalsCompanion.insert(
        id: const Value('${_demoPrefix}goal-trip'),
        title: 'Plan a family trip',
        type: const Value('generic'),
        targetDate: Value(DateTime(now.year + 1, 1, 15)),
        targetValue: const Value(100.0),
        currentValue: const Value(45.0),
        createdAt: Value(DateTime(now.year, 4, 1)),
      ),
      GoalsCompanion.insert(
        id: const Value('${_demoPrefix}goal-course'),
        title: 'Finish professional course',
        type: const Value('generic'),
        status: const Value('completed'),
        targetValue: const Value(12.0),
        currentValue: const Value(12.0),
        createdAt: Value(DateTime(now.year - 1, 6, 1)),
      ),
    ];
    await _db.batch((batch) {
      batch.insertAll(_db.goals, goals);
      batch.insertAll(_db.goalLinks, [
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-emergency'),
          goalId: '${_demoPrefix}goal-emergency',
          linkedType: 'account',
          linkedId: accountIds['savings']!,
        ),
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-fitness'),
          goalId: '${_demoPrefix}goal-fitness',
          linkedType: 'habit',
          linkedId: habitIds['exercise']!,
        ),
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-reading'),
          goalId: '${_demoPrefix}goal-reading',
          linkedType: 'habit',
          linkedId: habitIds['reading']!,
        ),
      ]);
      batch.insertAll(_db.goalMilestones, [
        GoalMilestonesCompanion.insert(
          id: const Value('${_demoPrefix}milestone-emergency-1'),
          goalId: '${_demoPrefix}goal-emergency',
          title: 'Save first ₹3 lakh',
          completed: const Value(true),
          sortOrder: const Value(0),
        ),
        GoalMilestonesCompanion.insert(
          id: const Value('${_demoPrefix}milestone-emergency-2'),
          goalId: '${_demoPrefix}goal-emergency',
          title: 'Reach ₹6 lakh',
          completed: const Value(true),
          sortOrder: const Value(1),
        ),
        GoalMilestonesCompanion.insert(
          id: const Value('${_demoPrefix}milestone-emergency-3'),
          goalId: '${_demoPrefix}goal-emergency',
          title: 'Reach final target',
          sortOrder: const Value(2),
        ),
        GoalMilestonesCompanion.insert(
          id: const Value('${_demoPrefix}milestone-trip-1'),
          goalId: '${_demoPrefix}goal-trip',
          title: 'Choose destination',
          completed: const Value(true),
          sortOrder: const Value(0),
        ),
        GoalMilestonesCompanion.insert(
          id: const Value('${_demoPrefix}milestone-trip-2'),
          goalId: '${_demoPrefix}goal-trip',
          title: 'Book travel and hotel',
          sortOrder: const Value(1),
        ),
      ]);
    });
  }

  /// Folders for both scopes. Documents folders carry the icon/colour the
  /// grid renders; notes folders deliberately leave both null, which is the
  /// "module default" path through `FolderTile`.
  Future<Map<String, String>> _insertFolders(DateTime now) async {
    const docFolders = [
      ('identity', 'Identity', 'id-card', '#4B7BA6'),
      ('financial', 'Financial', 'banknote', '#C49A3D'),
      ('insurance', 'Insurance', 'shield', '#3E7C5A'),
      ('property', 'Property', 'house', '#C2703D'),
      ('medical', 'Medical', 'heart', '#B85C6E'),
      ('receipts', 'Receipts', 'receipt', '#7C6BC4'),
      ('vehicle', 'Vehicle', 'car', '#5A6B7C'),
      // Deliberately empty — exercises the "0 documents" tile.
      ('travel', 'Travel', 'plane', '#3FA6A0'),
    ];
    const noteFolders = [
      ('work', 'Work'),
      ('personal', 'Personal'),
      ('ideas', 'Ideas'),
    ];

    final ids = <String, String>{
      for (final f in docFolders) f.$1: '${_demoPrefix}folder-${f.$1}',
      for (final f in noteFolders) f.$1: '${_demoPrefix}folder-${f.$1}',
      'taxreturns': '${_demoPrefix}folder-taxreturns',
    };

    await _db.batch((batch) {
      batch.insertAll(_db.folders, [
        for (final f in docFolders)
          FoldersCompanion.insert(
            id: Value(ids[f.$1]!),
            name: f.$2,
            iconName: Value(f.$3),
            colorHex: Value(f.$4),
            scope: 'documents',
            createdAt: Value(now.subtract(const Duration(days: 200))),
          ),
        for (final f in noteFolders)
          FoldersCompanion.insert(
            id: Value(ids[f.$1]!),
            name: f.$2,
            scope: 'notes',
            createdAt: Value(now.subtract(const Duration(days: 200))),
          ),
      ]);
    });

    // Nested folder — inserted second so the parent FK resolves.
    await _db.batch((batch) {
      batch.insert(
        _db.folders,
        FoldersCompanion.insert(
          id: Value(ids['taxreturns']!),
          name: 'Tax Returns',
          iconName: const Value('briefcase'),
          colorHex: const Value('#2D6B4F'),
          scope: 'documents',
          parentFolderId: Value(ids['financial']),
          createdAt: Value(now.subtract(const Duration(days: 180))),
        ),
      );
    });
    return ids;
  }

  /// Document metadata only — no bytes are written to disk, so thumbnails
  /// fall back to the type icon and opening one will report a missing file.
  /// Keeping this service filesystem-free is what lets it run against the
  /// in-memory database in tests, where `path_provider` isn't available.
  Future<Map<String, String>> _insertDocuments(
    DateTime now,
    Map<String, String> folderIds,
  ) async {
    // (key, title, type, folderKey, mime, ext, sizeBytes, pinned)
    const defs = [
      ('aadhaar', 'Aadhaar Card', 'identity', 'identity', 'image/jpeg', 'jpg', 842_113, true),
      ('pan', 'PAN Card', 'identity', 'identity', 'image/jpeg', 'jpg', 512_004, true),
      ('passport', 'Passport (2029 expiry)', 'identity', 'identity', 'application/pdf', 'pdf', 2_284_991, false),
      ('driving', 'Driving Licence', 'identity', 'vehicle', 'image/png', 'png', 1_104_220, false),
      ('salary', 'Salary Slip — March', 'financial', 'financial', 'application/pdf', 'pdf', 184_320, false),
      ('form16', 'Form 16 (FY 2024-25)', 'financial', 'taxreturns', 'application/pdf', 'pdf', 398_117, true),
      ('itr', 'ITR Acknowledgement', 'financial', 'taxreturns', 'application/pdf', 'pdf', 122_880, false),
      ('bankstmt', 'Bank Statement — Q1', 'financial', 'financial', 'application/vnd.ms-excel', 'xls', 61_440, false),
      ('healthins', 'Health Insurance Policy', 'insurance', 'insurance', 'application/pdf', 'pdf', 1_548_288, true),
      ('motorins', 'Car Insurance Policy', 'insurance', 'insurance', 'application/pdf', 'pdf', 904_221, false),
      ('lease', 'Rental Agreement', 'property', 'property', 'application/pdf', 'pdf', 3_211_776, false),
      ('ecbill', 'Electricity Bill — Feb', 'property', 'property', 'image/jpeg', 'jpg', 288_004, false),
      ('bloodtest', 'Blood Test Report', 'medical', 'medical', 'application/pdf', 'pdf', 442_368, false),
      ('prescription', 'Prescription — Dr. Rao', 'medical', 'medical', 'image/jpeg', 'jpg', 196_608, false),
      ('vaccine', 'Vaccination Certificate', 'medical', 'medical', 'application/pdf', 'pdf', 88_064, false),
      ('degree', 'Degree Certificate', 'education', 'identity', 'application/pdf', 'pdf', 1_887_436, false),
      ('resume', 'Resume 2026', 'education', null, 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'docx', 45_056, false),
      // Unfiled + untyped — the plainest row the list has to render.
      ('scratch', 'Scanned notes (untitled)', null, null, 'image/png', 'png', 733_184, false),
      // Zero-byte file: the size formatter's lower edge.
      ('empty', 'Empty placeholder.txt', 'other', null, 'text/plain', 'txt', 0, false),
      // Very large file: the size formatter's upper edge.
      ('archive', 'Property documents archive', 'property', 'property', 'application/pdf', 'pdf', 48_234_496, false),
      // Receipts, referenced by transactions below.
      ('receipt1', 'Receipt — Fresh Market', 'financial', 'receipts', 'image/jpeg', 'jpg', 154_112, false),
      ('receipt2', 'Receipt — Laptop stand', 'financial', 'receipts', 'image/jpeg', 'jpg', 231_424, false),
      ('receipt3', 'Invoice — Annual hosting', 'financial', 'receipts', 'application/pdf', 'pdf', 76_800, false),
    ];

    final ids = <String, String>{
      for (final d in defs) d.$1: '${_demoPrefix}document-${d.$1}',
    };

    await _db.batch((batch) {
      batch.insertAll(_db.documents, [
        for (var i = 0; i < defs.length; i++)
          () {
            final d = defs[i];
            return DocumentsCompanion.insert(
              id: Value(ids[d.$1]!),
              title: d.$2,
              filePath: 'documents/${ids[d.$1]}.${d.$6}',
              mimeType: d.$5,
              sizeBytes: Value(d.$7),
              folderId: Value(d.$4 == null ? null : folderIds[d.$4!]),
              isPinned: Value(d.$8),
              documentType: Value(d.$3),
              createdAt: Value(now.subtract(Duration(days: 3 * (i + 1)))),
            );
          }(),
      ]);
    });
    return ids;
  }

  /// Bills, recurring templates, budgets and one-off transactions chosen so
  /// every branch of the finance UI has a row that reaches it: overdue vs
  /// due-today, over- vs under-budget, paused vs active, and so on.
  /// Returns how many [Transactions] rows it added.
  Future<int> _insertFinanceEdgeCases(
    DateTime now,
    Map<String, String> accountIds,
    Map<String, String> categoryIds,
    Map<String, String> documentIds,
  ) async {
    final today = dateOnly(now);
    final month = DateTime(now.year, now.month);

    final extraTransactions = <TransactionsCompanion>[
      // Today — so "today" groupings are never empty.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-today-coffee'),
        accountId: accountIds['cash']!,
        categoryId: Value(categoryIds['Dining']),
        merchant: 'Morning coffee',
        amountMinor: -18000,
        date: DateTime(today.year, today.month, today.day, 9, 15),
        paymentMode: const Value('cash'),
        createdAt: Value(now),
      ),
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-today-groceries'),
        accountId: accountIds['checking']!,
        categoryId: Value(categoryIds['Groceries']),
        merchant: 'Fresh Market',
        amountMinor: -132550,
        date: DateTime(today.year, today.month, today.day, 18, 40),
        note: const Value('Weekly groceries run'),
        paymentMode: const Value('upi'),
        receiptDocumentId: Value(documentIds['receipt1']),
        createdAt: Value(now),
      ),
      // Receipt attached, card payment.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-receipt-laptop'),
        accountId: accountIds['credit']!,
        merchant: 'Laptop stand',
        amountMinor: -519900,
        date: now.subtract(const Duration(days: 4)),
        note: const Value('Desk setup — has receipt'),
        paymentMode: const Value('card'),
        receiptDocumentId: Value(documentIds['receipt2']),
        createdAt: Value(now.subtract(const Duration(days: 4))),
      ),
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-receipt-hosting'),
        accountId: accountIds['credit']!,
        categoryId: Value(categoryIds['Subscriptions']),
        merchant: 'Annual hosting',
        amountMinor: -899000,
        date: now.subtract(const Duration(days: 11)),
        paymentMode: const Value('net_banking'),
        receiptDocumentId: Value(documentIds['receipt3']),
        createdAt: Value(now.subtract(const Duration(days: 11))),
      ),
      // Uncategorised — the "no category" bucket in the spend analyzer.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-uncategorised'),
        accountId: accountIds['wallet']!,
        merchant: 'Unlabelled UPI transfer',
        amountMinor: -75000,
        date: now.subtract(const Duration(days: 2)),
        paymentMode: const Value('upi'),
        createdAt: Value(now.subtract(const Duration(days: 2))),
      ),
      // 'other' payment mode — the last unexercised mode.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-other-mode'),
        accountId: accountIds['checking']!,
        categoryId: Value(categoryIds['Entertainment']),
        merchant: 'Gift voucher redemption',
        amountMinor: -50000,
        date: now.subtract(const Duration(days: 6)),
        paymentMode: const Value('other'),
        createdAt: Value(now.subtract(const Duration(days: 6))),
      ),
      // Refund: a positive amount on an expense category.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-refund'),
        accountId: accountIds['credit']!,
        categoryId: Value(categoryIds['Entertainment']),
        merchant: 'Refund — cancelled booking',
        amountMinor: 240000,
        date: now.subtract(const Duration(days: 8)),
        note: const Value('Credited back to card'),
        paymentMode: const Value('card'),
        createdAt: Value(now.subtract(const Duration(days: 8))),
      ),
      // Smallest meaningful amount — ₹1.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-tiny'),
        accountId: accountIds['wallet']!,
        categoryId: Value(categoryIds['Transport']),
        merchant: 'Parking top-up',
        amountMinor: -100,
        date: now.subtract(const Duration(days: 1)),
        paymentMode: const Value('upi'),
        createdAt: Value(now.subtract(const Duration(days: 1))),
      ),
      // Very large amount — crore-scale formatting.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-huge'),
        accountId: accountIds['brokerage']!,
        categoryId: Value(categoryIds['Income']),
        merchant: 'Equity portfolio payout',
        amountMinor: 125000000,
        date: now.subtract(const Duration(days: 15)),
        note: const Value('Large credit — tests wide number layout'),
        paymentMode: const Value('net_banking'),
        createdAt: Value(now.subtract(const Duration(days: 15))),
      ),
      // On a deactivated account — must stay in history, out of totals.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-closed-account'),
        accountId: accountIds['closed']!,
        categoryId: Value(categoryIds['Income']),
        merchant: 'Final settlement',
        amountMinor: 4500000,
        date: DateTime(now.year - 1, now.month, 15),
        paymentMode: const Value('net_banking'),
        createdAt: Value(DateTime(now.year - 1, now.month, 15)),
      ),
      // Foreign-currency account.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-foreign'),
        accountId: accountIds['foreign']!,
        categoryId: Value(categoryIds['Dining']),
        merchant: 'Airport lounge',
        amountMinor: -3200,
        date: now.subtract(const Duration(days: 22)),
        paymentMode: const Value('card'),
        createdAt: Value(now.subtract(const Duration(days: 22))),
      ),
      // Loan EMI against the liability account.
      TransactionsCompanion.insert(
        id: const Value('${_demoPrefix}txn-emi'),
        accountId: accountIds['loan']!,
        categoryId: Value(categoryIds['Rent']),
        merchant: 'Home loan EMI',
        amountMinor: -4250000,
        date: DateTime(now.year, now.month, 5),
        paymentMode: const Value('net_banking'),
        createdAt: Value(DateTime(now.year, now.month, 5)),
      ),
    ];

    await _db.batch((batch) {
      batch.insertAll(_db.transactions, extraTransactions);

      batch.insertAll(_db.bills, [
        // Overdue, with an alarm-style reminder two days ahead.
        BillsCompanion.insert(
          id: const Value('${_demoPrefix}bill-overdue-broadband'),
          name: 'Broadband (overdue)',
          accountId: Value(accountIds['checking']),
          categoryId: Value(categoryIds['Subscriptions']),
          amountMinor: 119900,
          dueDate: today.subtract(const Duration(days: 6)),
          reminderMode: const Value('alarm'),
          reminderDaysBefore: const Value(2),
        ),
        // Due today.
        BillsCompanion.insert(
          id: const Value('${_demoPrefix}bill-due-today-water'),
          name: 'Water bill',
          accountId: Value(accountIds['checking']),
          amountMinor: 42000,
          dueDate: today,
        ),
        // Due in three days.
        BillsCompanion.insert(
          id: const Value('${_demoPrefix}bill-soon-gas'),
          name: 'Piped gas',
          accountId: Value(accountIds['checking']),
          amountMinor: 68500,
          dueDate: today.add(const Duration(days: 3)),
          reminderDaysBefore: const Value(1),
        ),
        // One-off, already paid and archived.
        BillsCompanion.insert(
          id: const Value('${_demoPrefix}bill-paid-once'),
          name: 'Society maintenance (one-time)',
          accountId: Value(accountIds['savings']),
          amountMinor: 1500000,
          dueDate: today.subtract(const Duration(days: 40)),
          frequency: const Value('once'),
          lastPaidDate: Value(today.subtract(const Duration(days: 41))),
          active: const Value(false),
        ),
        // Reminder switched off entirely.
        BillsCompanion.insert(
          id: const Value('${_demoPrefix}bill-no-reminder'),
          name: 'Newspaper subscription',
          accountId: Value(accountIds['cash']),
          amountMinor: 45000,
          dueDate: today.add(const Duration(days: 12)),
          reminderEnabled: const Value(false),
        ),
        // Far-future yearly bill, paid once before.
        BillsCompanion.insert(
          id: const Value('${_demoPrefix}bill-yearly-domain'),
          name: 'Domain renewal',
          accountId: Value(accountIds['credit']),
          categoryId: Value(categoryIds['Subscriptions']),
          amountMinor: 129900,
          dueDate: DateTime(now.year + 1, now.month, 18),
          frequency: const Value('yearly'),
          lastPaidDate: Value(DateTime(now.year, now.month, 18)),
          reminderDaysBefore: const Value(7),
        ),
      ]);

      batch.insertAll(_db.recurringTransactions, [
        // Daily — the highest-frequency template.
        RecurringTransactionsCompanion.insert(
          id: const Value('${_demoPrefix}recurring-daily-commute'),
          accountId: accountIds['wallet']!,
          categoryId: Value(categoryIds['Transport']),
          merchant: 'Daily commute',
          amountMinor: -6000,
          frequency: const Value('daily'),
          nextDueDate: today.add(const Duration(days: 1)),
          paymentMode: const Value('upi'),
        ),
        // Weekly.
        RecurringTransactionsCompanion.insert(
          id: const Value('${_demoPrefix}recurring-weekly-help'),
          accountId: accountIds['cash']!,
          merchant: 'Household help',
          amountMinor: -150000,
          frequency: const Value('weekly'),
          nextDueDate: today.add(const Duration(days: 4)),
          paymentMode: const Value('cash'),
        ),
        // Yearly, with a defined end date.
        RecurringTransactionsCompanion.insert(
          id: const Value('${_demoPrefix}recurring-yearly-premium'),
          accountId: accountIds['savings']!,
          merchant: 'Term insurance premium',
          amountMinor: -1850000,
          frequency: const Value('yearly'),
          nextDueDate: DateTime(now.year + 1, 4, 10),
          endDate: Value(DateTime(now.year + 8, 4, 10)),
          paymentMode: const Value('net_banking'),
        ),
        // Overdue: nextDueDate in the past, so a catch-up run has work to do.
        RecurringTransactionsCompanion.insert(
          id: const Value('${_demoPrefix}recurring-overdue-gym'),
          accountId: accountIds['credit']!,
          categoryId: Value(categoryIds['Subscriptions']),
          merchant: 'Gym membership',
          amountMinor: -250000,
          frequency: const Value('monthly'),
          nextDueDate: today.subtract(const Duration(days: 9)),
          paymentMode: const Value('card'),
        ),
        // Paused — keeps its schedule but must not generate.
        RecurringTransactionsCompanion.insert(
          id: const Value('${_demoPrefix}recurring-paused-magazine'),
          accountId: accountIds['credit']!,
          categoryId: Value(categoryIds['Subscriptions']),
          merchant: 'Magazine subscription (paused)',
          amountMinor: -39900,
          frequency: const Value('monthly'),
          nextDueDate: today.add(const Duration(days: 20)),
          active: const Value(false),
          paymentMode: const Value('card'),
        ),
        // Already ended — endDate is in the past.
        RecurringTransactionsCompanion.insert(
          id: const Value('${_demoPrefix}recurring-ended-course'),
          accountId: accountIds['checking']!,
          merchant: 'Online course instalment',
          amountMinor: -300000,
          frequency: const Value('monthly'),
          nextDueDate: today.subtract(const Duration(days: 30)),
          endDate: Value(today.subtract(const Duration(days: 25))),
          active: const Value(false),
          paymentMode: const Value('net_banking'),
        ),
      ]);

      batch.insertAll(_db.budgets, [
        // Deliberately far below this month's actual dining spend.
        BudgetsCompanion.insert(
          id: const Value('${_demoPrefix}budget-current-dining-over'),
          categoryId: categoryIds['Dining']!,
          limitMinor: 200000,
          startDate: month,
          effectiveMonth: Value(month),
          createdAt: Value(month),
        ),
        // Comfortably above actual spend.
        BudgetsCompanion.insert(
          id: const Value('${_demoPrefix}budget-current-groceries-under'),
          categoryId: categoryIds['Groceries']!,
          limitMinor: 3000000,
          startDate: month,
          effectiveMonth: Value(month),
          createdAt: Value(month),
        ),
        // Weekly period rather than monthly.
        BudgetsCompanion.insert(
          id: const Value('${_demoPrefix}budget-current-transport-weekly'),
          categoryId: categoryIds['Transport']!,
          period: const Value('weekly'),
          limitMinor: 150000,
          startDate: month,
          effectiveMonth: Value(month),
          createdAt: Value(month),
        ),
        // Tombstone: "no budget for Entertainment from this month on".
        BudgetsCompanion.insert(
          id: const Value('${_demoPrefix}budget-current-entertainment-off'),
          categoryId: categoryIds['Entertainment']!,
          limitMinor: 0,
          startDate: month,
          effectiveMonth: Value(month),
          active: const Value(false),
          createdAt: Value(month),
        ),
        // A second version of the same category, effective next month —
        // proves editing a limit doesn't rewrite the current month.
        BudgetsCompanion.insert(
          id: const Value('${_demoPrefix}budget-next-dining-raised'),
          categoryId: categoryIds['Dining']!,
          limitMinor: 700000,
          startDate: DateTime(month.year, month.month + 1),
          effectiveMonth: Value(DateTime(month.year, month.month + 1)),
          createdAt: Value(month),
        ),
      ]);
    });

    return extraTransactions.length;
  }

  /// Habits covering every state the overview and detail screens branch on:
  /// measured vs binary, paused vs running, scheduled vs daily, a long
  /// streak, a deliberately broken one, and a brand-new habit with no
  /// history at all. Returns how many [HabitLogs] rows it added.
  Future<int> _insertHabitEdgeCases(
    DateTime now,
    Map<String, String> categoryIds,
  ) async {
    final today = dateOnly(now);

    // Two closed pause ranges, plus a live one set below.
    final pastPauses = jsonEncode([
      [
        today.subtract(const Duration(days: 120)).toIso8601String(),
        today.subtract(const Duration(days: 110)).toIso8601String(),
      ],
      [
        today.subtract(const Duration(days: 60)).toIso8601String(),
        today.subtract(const Duration(days: 55)).toIso8601String(),
      ],
    ]);

    // Weekly on Mon/Wed/Fri, driven by an encoded RepeatSchedule rather than
    // the plain `frequency` column.
    final mwfSchedule = RepeatSchedule(
      start: today.subtract(const Duration(days: 90)),
      frequency: 'weekly',
      weekdays: const [1, 3, 5],
    ).encode();

    // A schedule that has already ended — nothing should be due from it.
    final endedSchedule = RepeatSchedule(
      start: today.subtract(const Duration(days: 200)),
      frequency: 'daily',
      end: today.subtract(const Duration(days: 30)),
    ).encode();

    await _db.batch((batch) {
      batch.insertAll(_db.habits, [
        // Measured habit — amount + unit, so logs carry a quantity.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-water-qty'),
          name: 'Drink 3 litres of water',
          description: const Value('Spread across the day, not all at once.'),
          frequency: const Value('daily'),
          targetAmount: const Value(3.0),
          targetUnit: const Value('litres'),
          categoryId: Value(categoryIds['Wellness']),
          createdAt: Value(today.subtract(const Duration(days: 75))),
        ),
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-pages-qty'),
          name: 'Read 25 pages',
          frequency: const Value('daily'),
          targetAmount: const Value(25.0),
          targetUnit: const Value('pages'),
          categoryId: Value(categoryIds['Learning']),
          createdAt: Value(today.subtract(const Duration(days: 75))),
        ),
        // Currently paused, and carrying two earlier closed pauses.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-paused-running'),
          name: 'Evening run',
          description: const Value('Paused while recovering from a sprain.'),
          frequency: const Value('custom'),
          targetPerWeek: const Value(3),
          categoryId: Value(categoryIds['Fitness']),
          pauseStartedAt: Value(today.subtract(const Duration(days: 4))),
          pausedUntil: Value(today.add(const Duration(days: 10))),
          pauseHistory: Value(pastPauses),
          createdAt: Value(today.subtract(const Duration(days: 150))),
        ),
        // Only due Mon/Wed/Fri.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-strength-mwf'),
          name: 'Strength training',
          frequency: const Value('weekly'),
          targetPerWeek: const Value(3),
          schedule: Value(mwfSchedule),
          categoryId: Value(categoryIds['Fitness']),
          reminderEnabled: const Value(true),
          reminderHour: const Value(6),
          reminderMinute: const Value(30),
          reminderMode: const Value('alarm'),
          createdAt: Value(today.subtract(const Duration(days: 90))),
        ),
        // Schedule already expired.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-ended-challenge'),
          name: '30-day cold shower challenge',
          frequency: const Value('daily'),
          schedule: Value(endedSchedule),
          createdAt: Value(today.subtract(const Duration(days: 200))),
        ),
        // Created today, zero logs — the empty-state path.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-brand-new'),
          name: 'Stretch for 5 minutes',
          description: const Value('Just started — no history yet.'),
          categoryId: Value(categoryIds['Wellness']),
          createdAt: Value(now),
        ),
        // Unbroken run, long enough to exercise streak formatting.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-long-streak'),
          name: 'Daily journal',
          frequency: const Value('daily'),
          reminderEnabled: const Value(true),
          reminderHour: const Value(21),
          reminderMinute: const Value(0),
          categoryId: Value(categoryIds['Wellness']),
          createdAt: Value(today.subtract(const Duration(days: 130))),
        ),
        // Logged consistently, then stopped — should raise a streak-risk
        // insight and render a zero current streak with a long best streak.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-broken-streak'),
          name: 'Practice guitar',
          frequency: const Value('daily'),
          categoryId: Value(categoryIds['Learning']),
          createdAt: Value(today.subtract(const Duration(days: 100))),
        ),
        // Once a week only — the sparsest target.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-weekly-review'),
          name: 'Weekly review',
          frequency: const Value('custom'),
          targetPerWeek: const Value(1),
          createdAt: Value(today.subtract(const Duration(days: 120))),
        ),
        // A second archived habit, this one with history behind it.
        HabitsCompanion.insert(
          id: const Value('${_demoPrefix}habit-archived-nosugar'),
          name: 'No sugar',
          archived: const Value(true),
          categoryId: Value(categoryIds['Wellness']),
          createdAt: Value(today.subtract(const Duration(days: 220))),
        ),
      ]);
    });

    final random = Random(20260901);
    final logs = <HabitLogsCompanion>[];

    void log(
      String habitKey,
      int dayOffset, {
      double? amount,
      double? target,
      String? unit,
      String? note,
      bool completed = true,
    }) {
      final date = today.subtract(Duration(days: dayOffset));
      logs.add(
        HabitLogsCompanion.insert(
          id: Value('$_demoPrefix$habitKey-log-$dayOffset'),
          habitId: '$_demoPrefix$habitKey',
          date: date,
          completed: Value(completed),
          amount: Value(amount),
          targetAmountSnapshot: Value(target),
          targetUnitSnapshot: Value(unit),
          notes: Value(note),
        ),
      );
    }

    // Measured habits: amounts above, at and below target, plus a logged
    // miss (completed == false) so that branch is represented.
    for (var d = 0; d < 70; d++) {
      if (random.nextDouble() < 0.88) {
        final litres = 1.2 + random.nextDouble() * 2.6;
        log(
          'habit-water-qty',
          d,
          amount: double.parse(litres.toStringAsFixed(1)),
          target: 3.0,
          unit: 'litres',
          completed: litres >= 3.0,
          note: d == 3 ? 'Hot day — drank extra' : null,
        );
      }
      if (random.nextDouble() < 0.7) {
        final pages = (8 + random.nextInt(34)).toDouble();
        log(
          'habit-pages-qty',
          d,
          amount: pages,
          target: 25.0,
          unit: 'pages',
          completed: pages >= 25,
        );
      }
    }

    // Unbroken: every day up to and including today.
    for (var d = 0; d < 130; d++) {
      log('habit-long-streak', d, note: d == 0 ? 'Day 130' : null);
    }

    // Broken 8 days ago after a 40-day run.
    for (var d = 8; d < 48; d++) {
      log('habit-broken-streak', d);
    }

    // Mon/Wed/Fri only, matching the encoded schedule.
    for (var d = 0; d < 90; d++) {
      final date = today.subtract(Duration(days: d));
      if (![1, 3, 5].contains(date.weekday)) continue;
      if (random.nextDouble() < 0.8) log('habit-strength-mwf', d);
    }

    // Once a week, on Sundays.
    for (var d = 0; d < 120; d++) {
      final date = today.subtract(Duration(days: d));
      if (date.weekday != DateTime.sunday) continue;
      if (random.nextDouble() < 0.75) log('habit-weekly-review', d);
    }

    // History behind the archived habit, so archiving isn't confused with
    // "never used".
    for (var d = 90; d < 200; d++) {
      if (random.nextDouble() < 0.6) log('habit-archived-nosugar', d);
    }

    // Ran only while its schedule was live.
    for (var d = 30; d < 60; d++) {
      log('habit-ended-challenge', d);
    }

    // Logged through the pauses too — a pause suppresses scheduling, not
    // the historical record.
    for (var d = 20; d < 150; d += 2) {
      log('habit-paused-running', d);
    }

    await _db.batch((batch) => batch.insertAll(_db.habitLogs, logs));
    return logs.length;
  }

  /// Tasks spanning every priority, status, due-date relation and reminder
  /// mode, plus a recurring series and a heavily-subtasked parent.
  /// Returns how many [Tasks] rows it added.
  Future<int> _insertTaskEdgeCases(
    DateTime now,
    Map<String, String> categoryIds,
  ) async {
    final today = dateOnly(now);
    const recurrenceId = '${_demoPrefix}task-recurrence-standup';
    final dailySchedule = RepeatSchedule(
      start: today.subtract(const Duration(days: 14)),
      frequency: 'daily',
      end: today.add(const Duration(days: 60)),
    ).encode();

    final tasks = <TasksCompanion>[
      // Badly overdue, highest priority, alarm reminder.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-overdue'),
        title: 'Renew car insurance',
        description: const Value('Policy lapsed — renew before driving again.'),
        dueDate: Value(DateTime(today.year, today.month, today.day - 9, 10)),
        priority: const Value('high'),
        reminderMode: const Value('alarm'),
        createdAt: Value(today.subtract(const Duration(days: 30))),
      ),
      // Overdue by a day.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-overdue-mild'),
        title: 'Submit reimbursement claim',
        dueDate: Value(DateTime(today.year, today.month, today.day - 1, 17)),
        priority: const Value('medium'),
        createdAt: Value(today.subtract(const Duration(days: 10))),
      ),
      // Due later today.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-due-today'),
        title: 'Call the dentist',
        dueDate: Value(DateTime(today.year, today.month, today.day, 16, 30)),
        priority: const Value('high'),
        createdAt: Value(today.subtract(const Duration(days: 3))),
      ),
      // Due tomorrow, alarm-style.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-due-tomorrow'),
        title: 'Pick up dry cleaning',
        dueDate: Value(DateTime(today.year, today.month, today.day + 1, 11)),
        priority: const Value('low'),
        reminderMode: const Value('alarm'),
        createdAt: Value(today.subtract(const Duration(days: 2))),
      ),
      // Far future.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-far-future'),
        title: 'Renew passport',
        description: const Value('Expires next year — start three months out.'),
        dueDate: Value(DateTime(today.year + 1, 2, 14, 9)),
        priority: const Value('medium'),
        reminderEnabled: const Value(false),
        createdAt: Value(today),
      ),
      // No due date at all — the "someday" bucket.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-no-due'),
        title: 'Sort out the loft',
        priority: const Value('low'),
        reminderEnabled: const Value(false),
        createdAt: Value(today.subtract(const Duration(days: 45))),
      ),
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-no-due-high'),
        title: 'Research index funds',
        description: const Value('No deadline, but worth doing properly.'),
        priority: const Value('high'),
        reminderEnabled: const Value(false),
        createdAt: Value(today.subtract(const Duration(days: 20))),
      ),
      // Completed today.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-done-today'),
        title: 'Pay electricity bill',
        dueDate: Value(DateTime(today.year, today.month, today.day, 12)),
        priority: const Value('high'),
        status: const Value('done'),
        completedAt: Value(now.subtract(const Duration(hours: 2))),
        createdAt: Value(today.subtract(const Duration(days: 5))),
      ),
      // Completed late — done after its due date.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-done-late'),
        title: 'File quarterly GST',
        dueDate: Value(DateTime(today.year, today.month, today.day - 14, 18)),
        priority: const Value('high'),
        status: const Value('done'),
        completedAt: Value(today.subtract(const Duration(days: 11))),
        createdAt: Value(today.subtract(const Duration(days: 40))),
      ),
      // A very long title and description — layout stress.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-long-text'),
        title:
            'Compare broadband providers, shortlist three, check installation '
            'lead times and cancel the existing connection once switched',
        description: const Value(
          'Current plan renews automatically at a higher rate. Need to compare '
          'at least three providers on price, actual measured speed, data caps '
          'and contract length, then confirm the new installation date before '
          'cancelling so there is no gap in service. Keep the final quotes in '
          'the Documents module for reference at the next renewal.',
        ),
        dueDate: Value(DateTime(today.year, today.month, today.day + 5, 19)),
        priority: const Value('medium'),
        createdAt: Value(today.subtract(const Duration(days: 7))),
      ),
      // Parent of a long subtask checklist.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-checklist'),
        title: 'Plan the weekend trip',
        description: const Value('Everything that has to happen before Friday.'),
        dueDate: Value(DateTime(today.year, today.month, today.day + 4, 20)),
        priority: const Value('medium'),
        createdAt: Value(today.subtract(const Duration(days: 12))),
      ),
      // Subtasks all ticked, parent still open — a deliberate mismatch.
      TasksCompanion.insert(
        id: const Value('${_demoPrefix}task-edge-subtasks-done'),
        title: 'Onboard the new laptop',
        dueDate: Value(DateTime(today.year, today.month, today.day + 2, 15)),
        priority: const Value('low'),
        createdAt: Value(today.subtract(const Duration(days: 6))),
      ),
    ];

    // Recurring daily stand-up: the head row plus generated occurrences,
    // mirroring how ScheduleCoordinator materialises a series.
    for (var i = 0; i < 10; i++) {
      final due = DateTime(today.year, today.month, today.day - 3 + i, 9, 30);
      final isHead = i == 0;
      tasks.add(
        TasksCompanion.insert(
          id: Value(
            isHead ? recurrenceId : '${_demoPrefix}task-standup-$i',
          ),
          title: 'Daily stand-up notes',
          dueDate: Value(due),
          priority: const Value('low'),
          status: Value(due.isBefore(now) ? 'done' : 'open'),
          completedAt: Value(
            due.isBefore(now) ? due.add(const Duration(minutes: 20)) : null,
          ),
          schedule: Value(dailySchedule),
          recurrenceId: const Value(recurrenceId),
          recurrenceNextGenerationDate: Value(
            isHead ? today.add(const Duration(days: 7)) : null,
          ),
          createdAt: Value(today.subtract(const Duration(days: 14))),
        ),
      );
    }

    await _db.batch((batch) => batch.insertAll(_db.tasks, tasks));

    await _db.batch((batch) {
      batch.insertAll(_db.subtasks, [
        for (final (i, item) in const [
          ('Book train tickets', true),
          ('Reserve the guest house', true),
          ('Check the weather forecast', false),
          ('Pack rain gear', false),
          ('Arrange pet sitting', false),
          ('Download offline maps', false),
        ].indexed)
          SubtasksCompanion.insert(
            id: Value('${_demoPrefix}subtask-trip-$i'),
            taskId: '${_demoPrefix}task-edge-checklist',
            title: item.$1,
            done: Value(item.$2),
          ),
        for (final (i, title) in const [
          'Install the toolchain',
          'Restore from backup',
          'Set up SSH keys',
        ].indexed)
          SubtasksCompanion.insert(
            id: Value('${_demoPrefix}subtask-laptop-$i'),
            taskId: '${_demoPrefix}task-edge-subtasks-done',
            title: title,
            done: const Value(true),
          ),
      ]);
    });

    return tasks.length;
  }

  /// Goals in every status and progress shape the cards render, including
  /// the awkward ones: zero progress past its deadline, progress beyond
  /// target, and automatic progress driven by a link rather than by hand.
  Future<void> _insertGoalEdgeCases(
    DateTime now,
    Map<String, String> accountIds,
    Map<String, String> habitIds,
  ) async {
    final today = dateOnly(now);

    await _db.batch((batch) {
      batch.insertAll(_db.goals, [
        // Untouched and already overdue.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-overdue'),
          title: 'Learn conversational Spanish',
          description: const Value('Deadline passed without any progress.'),
          type: const Value('generic'),
          targetDate: Value(today.subtract(const Duration(days: 20))),
          targetValue: const Value(100.0),
          currentValue: const Value(0.0),
          reminderEnabled: const Value(true),
          reminderDaysBefore: const Value(7),
          createdAt: Value(today.subtract(const Duration(days: 300))),
        ),
        // Exceeded its target — progress must clamp, not overflow.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-exceeded'),
          title: 'Walk 10,000 steps daily',
          type: const Value('habit'),
          targetDate: Value(DateTime(now.year, 12, 31)),
          targetValue: const Value(300.0),
          currentValue: const Value(342.0),
          progressMode: const Value('manual'),
          createdAt: Value(DateTime(now.year, 1, 1)),
        ),
        // Abandoned — the third status, previously unrepresented.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-abandoned'),
          title: 'Run a marathon this year',
          description: const Value('Dropped after an injury; kept for the record.'),
          type: const Value('habit'),
          status: const Value('abandoned'),
          targetDate: Value(DateTime(now.year, 10, 1)),
          targetValue: const Value(42.0),
          currentValue: const Value(11.0),
          createdAt: Value(DateTime(now.year, 2, 1)),
        ),
        // No target date at all.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-no-deadline'),
          title: 'Build a six-month runway',
          type: const Value('financial'),
          targetValue: const Value(900000.0),
          currentValue: const Value(310000.0),
          createdAt: Value(today.subtract(const Duration(days: 90))),
        ),
        // Progress derived from a linked habit rather than entered by hand.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-automatic'),
          title: 'Journal every day for a year',
          type: const Value('habit'),
          progressMode: const Value('automatic'),
          targetDate: Value(DateTime(now.year + 1, now.month, now.day)),
          targetValue: const Value(365.0),
          currentValue: const Value(130.0),
          reminderEnabled: const Value(true),
          reminderMode: const Value('alarm'),
          reminderDaysBefore: const Value(0),
          createdAt: Value(today.subtract(const Duration(days: 130))),
        ),
        // Deadline inside the week — the "due soon" treatment.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-due-soon'),
          title: 'Finish tax filing',
          type: const Value('generic'),
          targetDate: Value(today.add(const Duration(days: 4))),
          targetValue: const Value(5.0),
          currentValue: const Value(3.0),
          reminderEnabled: const Value(true),
          reminderDaysBefore: const Value(2),
          createdAt: Value(today.subtract(const Duration(days: 60))),
        ),
        // Brand new, nothing logged, no milestones.
        GoalsCompanion.insert(
          id: const Value('${_demoPrefix}goal-edge-fresh'),
          title: 'Declutter the apartment',
          type: const Value('generic'),
          targetValue: const Value(12.0),
          currentValue: const Value(0.0),
          createdAt: Value(now),
        ),
      ]);

      batch.insertAll(_db.goalLinks, [
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-automatic-journal'),
          goalId: '${_demoPrefix}goal-edge-automatic',
          linkedType: 'habit',
          linkedId: '${_demoPrefix}habit-long-streak',
        ),
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-runway-savings'),
          goalId: '${_demoPrefix}goal-edge-no-deadline',
          linkedType: 'account',
          linkedId: accountIds['savings']!,
        ),
        // Second account on the same goal — the many-to-many really is many.
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-runway-brokerage'),
          goalId: '${_demoPrefix}goal-edge-no-deadline',
          linkedType: 'account',
          linkedId: accountIds['brokerage']!,
        ),
        // Link to a task rather than a habit or account.
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-tax-task'),
          goalId: '${_demoPrefix}goal-edge-due-soon',
          linkedType: 'task',
          linkedId: '${_demoPrefix}task-edge-overdue',
        ),
        GoalLinksCompanion.insert(
          id: const Value('${_demoPrefix}goal-link-marathon-habit'),
          goalId: '${_demoPrefix}goal-edge-abandoned',
          linkedType: 'habit',
          linkedId: habitIds['exercise']!,
        ),
      ]);

      batch.insertAll(_db.goalMilestones, [
        // Every milestone ticked while the goal itself is still short of
        // target — milestones are organisational, not a progress source.
        for (final (i, title) in const [
          'Gather Form 16',
          'Reconcile capital gains',
          'Claim 80C deductions',
        ].indexed)
          GoalMilestonesCompanion.insert(
            id: Value('${_demoPrefix}milestone-tax-$i'),
            goalId: '${_demoPrefix}goal-edge-due-soon',
            title: title,
            completed: const Value(true),
            sortOrder: Value(i),
          ),
        // None ticked.
        for (final (i, title) in const [
          'Pick a course',
          'Study 20 minutes a day',
          'Hold a five-minute conversation',
        ].indexed)
          GoalMilestonesCompanion.insert(
            id: Value('${_demoPrefix}milestone-spanish-$i'),
            goalId: '${_demoPrefix}goal-edge-overdue',
            title: title,
            sortOrder: Value(i),
          ),
      ]);
    });
  }

  /// Calendar entries covering recurrence (all four frequencies, head rows
  /// plus generated occurrences), reminders, zero-length and multi-day
  /// spans, and each polymorphic `sourceType`.
  /// Returns how many [Events] rows it added.
  Future<int> _insertEventEdgeCases(DateTime now) async {
    final today = dateOnly(now);
    final events = <EventsCompanion>[];

    void event(
      String id,
      String title,
      DateTime start, {
      DateTime? end,
      String? description,
      String sourceType = 'manual',
      String? sourceId,
      String frequency = 'none',
      String? recurrenceId,
      DateTime? recurrenceEndDate,
      DateTime? nextGeneration,
      String? schedule,
      bool reminderEnabled = false,
      String reminderMode = 'notification',
      int reminderMinutesBefore = 0,
    }) {
      events.add(
        EventsCompanion.insert(
          id: Value(id),
          title: title,
          description: Value(description),
          startTime: start,
          endTime: Value(end),
          sourceType: Value(sourceType),
          sourceId: Value(sourceId),
          frequency: Value(frequency),
          recurrenceEndDate: Value(recurrenceEndDate),
          recurrenceId: Value(recurrenceId),
          recurrenceNextGenerationDate: Value(nextGeneration),
          schedule: Value(schedule),
          reminderEnabled: Value(reminderEnabled),
          reminderMode: Value(reminderMode),
          reminderMinutesBefore: Value(reminderMinutesBefore),
          createdAt: Value(now.subtract(const Duration(days: 30))),
        ),
      );
    }

    // Three today, so the dashboard's "now" hero and the day view are busy:
    // one already finished, one in progress, one still to come.
    event(
      '${_demoPrefix}event-today-past',
      'Team stand-up',
      DateTime(today.year, today.month, today.day, 9, 30),
      end: DateTime(today.year, today.month, today.day, 9, 45),
      description: 'Already finished earlier today.',
    );
    event(
      '${_demoPrefix}event-today-now',
      'Focus block — deep work',
      now.subtract(const Duration(minutes: 20)),
      end: now.add(const Duration(minutes: 40)),
      description: 'Spans the current moment.',
      reminderEnabled: true,
      reminderMinutesBefore: 10,
    );
    event(
      '${_demoPrefix}event-today-later',
      'Physiotherapy appointment',
      DateTime(today.year, today.month, today.day, 19, 0),
      end: DateTime(today.year, today.month, today.day, 20, 0),
      reminderEnabled: true,
      reminderMode: 'alarm',
      reminderMinutesBefore: 60,
    );
    // No end time — an instant, not a span.
    event(
      '${_demoPrefix}event-instant',
      'Medication reminder',
      DateTime(today.year, today.month, today.day, 22, 0),
      reminderEnabled: true,
      reminderMinutesBefore: 0,
    );
    // Multi-day span.
    event(
      '${_demoPrefix}event-multiday',
      'Family visiting',
      DateTime(today.year, today.month, today.day + 8, 10),
      end: DateTime(today.year, today.month, today.day + 12, 18),
      description: 'Crosses several days — tests multi-day rendering.',
    );
    // Full-day span (midnight to midnight).
    event(
      '${_demoPrefix}event-allday',
      'Public holiday',
      DateTime(today.year, today.month, today.day + 15),
      end: DateTime(today.year, today.month, today.day + 16),
    );
    // Sourced from other modules — the polymorphic reference.
    event(
      '${_demoPrefix}event-source-task',
      'Renew car insurance',
      DateTime(today.year, today.month, today.day - 9, 10),
      sourceType: 'task',
      sourceId: '${_demoPrefix}task-edge-overdue',
    );
    event(
      '${_demoPrefix}event-source-goal',
      'Tax filing deadline',
      DateTime(today.year, today.month, today.day + 4, 9),
      sourceType: 'goal',
      sourceId: '${_demoPrefix}goal-edge-due-soon',
    );
    event(
      '${_demoPrefix}event-source-habit',
      'Strength training',
      DateTime(today.year, today.month, today.day, 6, 30),
      end: DateTime(today.year, today.month, today.day, 7, 30),
      sourceType: 'habit',
      sourceId: '${_demoPrefix}habit-strength-mwf',
    );

    // Four recurring series. Only the head row carries the frequency and the
    // generation bookkeeping; occurrences are plain rows sharing recurrenceId.
    void series({
      required String key,
      required String title,
      required String frequency,
      required int stepDays,
      required int count,
      required int hour,
      DateTime? endDate,
    }) {
      final headId = '$_demoPrefix$key';
      final start = DateTime(today.year, today.month, today.day, hour);
      final schedule = RepeatSchedule(
        start: start,
        frequency: frequency,
      ).encode();
      event(
        headId,
        title,
        start,
        end: start.add(const Duration(hours: 1)),
        frequency: frequency,
        recurrenceId: headId,
        recurrenceEndDate: endDate,
        nextGeneration: start.add(Duration(days: stepDays * count)),
        schedule: schedule,
        reminderEnabled: true,
        reminderMinutesBefore: 15,
      );
      for (var i = 1; i < count; i++) {
        final occurrence = DateTime(
          start.year,
          frequency == 'monthly' ? start.month + i : start.month,
          frequency == 'monthly' ? start.day : start.day + stepDays * i,
          hour,
        );
        event(
          '$headId-occurrence-$i',
          title,
          occurrence,
          end: occurrence.add(const Duration(hours: 1)),
          recurrenceId: headId,
        );
      }
    }

    series(
      key: 'event-series-weekly',
      title: 'Weekly planning',
      frequency: 'weekly',
      stepDays: 7,
      count: 8,
      hour: 18,
      endDate: today.add(const Duration(days: 120)),
    );
    series(
      key: 'event-series-daily',
      title: 'Evening walk',
      frequency: 'daily',
      stepDays: 1,
      count: 14,
      hour: 20,
    );
    series(
      key: 'event-series-monthly',
      title: 'Rent transfer',
      frequency: 'monthly',
      stepDays: 30,
      count: 6,
      hour: 11,
    );

    // Yearly head with no generated occurrences yet.
    final anniversary = DateTime(now.year, 11, 12, 9);
    event(
      '${_demoPrefix}event-series-yearly',
      'Work anniversary',
      anniversary,
      end: anniversary.add(const Duration(hours: 1)),
      frequency: 'yearly',
      recurrenceId: '${_demoPrefix}event-series-yearly',
      nextGeneration: DateTime(now.year + 1, 11, 12, 9),
      reminderEnabled: true,
      reminderMinutesBefore: 1440,
    );

    await _db.batch((batch) => batch.insertAll(_db.events, events));
    return events.length;
  }

  /// Tags shared across notes, documents, tasks and goals — the point of
  /// [EntityTags] is that one tag spans modules, so each tag here is used by
  /// more than one entity type.
  Future<void> _insertTags(
    DateTime now,
    Map<String, String> documentIds,
  ) async {
    const tagNames = [
      'important',
      'urgent',
      'personal',
      'work',
      'finance',
      'health',
      'reference',
      'archive',
    ];
    final tagIds = {
      for (final n in tagNames) n: '${_demoPrefix}tag-$n',
    };

    // (tag, entityType, entityId)
    final links = <(String, String, String)>[
      ('important', 'document', documentIds['aadhaar']!),
      ('important', 'document', documentIds['passport']!),
      ('reference', 'document', documentIds['form16']!),
      ('finance', 'document', documentIds['form16']!),
      ('finance', 'document', documentIds['bankstmt']!),
      ('health', 'document', documentIds['bloodtest']!),
      ('health', 'document', documentIds['healthins']!),
      ('archive', 'document', documentIds['itr']!),
      ('personal', 'document', documentIds['degree']!),
      ('work', 'document', documentIds['resume']!),
      ('urgent', 'task', '${_demoPrefix}task-edge-overdue'),
      ('important', 'task', '${_demoPrefix}task-edge-overdue'),
      ('finance', 'task', '${_demoPrefix}task-edge-done-late'),
      ('personal', 'task', '${_demoPrefix}task-edge-checklist'),
      ('work', 'task', '${_demoPrefix}task-edge-subtasks-done'),
      ('finance', 'goal', '${_demoPrefix}goal-edge-no-deadline'),
      ('important', 'goal', '${_demoPrefix}goal-edge-due-soon'),
      ('health', 'goal', '${_demoPrefix}goal-edge-abandoned'),
      ('personal', 'note', '${_demoPrefix}note-0'),
      ('reference', 'note', '${_demoPrefix}note-1'),
      ('work', 'note', '${_demoPrefix}note-7'),
      ('health', 'note', '${_demoPrefix}note-2'),
    ];

    await _db.batch((batch) {
      batch.insertAll(_db.tags, [
        for (final n in tagNames)
          TagsCompanion.insert(
            id: Value(tagIds[n]!),
            name: n,
            createdAt: Value(now.subtract(const Duration(days: 150))),
          ),
      ]);
    });
    await _db.batch((batch) {
      batch.insertAll(_db.entityTags, [
        for (final l in links)
          EntityTagsCompanion.insert(
            tagId: tagIds[l.$1]!,
            entityType: l.$2,
            entityId: l.$3,
          ),
      ]);
    });
  }

  /// Only *dismissed* insights are seeded. `InsightsRepository.reconcile`
  /// deletes any non-dismissed row the rule engine no longer produces, so a
  /// hand-written live insight would vanish on the next refresh — the live
  /// ones come from the rule engine running over the data above.
  Future<void> _insertDismissedInsights(DateTime now) async {
    await _db.batch((batch) {
      batch.insertAll(_db.insights, [
        InsightsCompanion.insert(
          id: const Value('${_demoPrefix}insight-dismissed-overspend'),
          type: 'overspend',
          severity: 'critical',
          title: 'Dining spend was 180% of budget last month',
          relatedModule: const Value('finance'),
          relatedEntityId: const Value('${_demoPrefix}category-dining'),
          generatedAt: Value(now.subtract(const Duration(days: 12))),
          dismissed: const Value(true),
        ),
        InsightsCompanion.insert(
          id: const Value('${_demoPrefix}insight-dismissed-streak'),
          type: 'streak_risk',
          severity: 'warning',
          title: 'Practice guitar is about to lose a 40-day streak',
          relatedModule: const Value('habits'),
          relatedEntityId: const Value('${_demoPrefix}habit-broken-streak'),
          generatedAt: Value(now.subtract(const Duration(days: 8))),
          dismissed: const Value(true),
        ),
        InsightsCompanion.insert(
          id: const Value('${_demoPrefix}insight-dismissed-momentum'),
          type: 'task_momentum',
          severity: 'good',
          title: 'You closed 14 tasks last week — your best run this quarter',
          relatedModule: const Value('tasks'),
          generatedAt: Value(now.subtract(const Duration(days: 5))),
          dismissed: const Value(true),
        ),
      ]);
    });
  }

  Future<void> _insertHealthData(DateTime now) async {
    const medDefs = [
      (
        id: '${_demoPrefix}med-vitamin-d',
        name: 'Vitamin D3',
        dosageNote: '1 capsule · with breakfast',
        slot: 'am',
        colorHex: '#C49A3D',
        stockLeft: 28,
        frequency: 'daily',
        timesCsv: '08:00',
      ),
      (
        id: '${_demoPrefix}med-omega-3',
        name: 'Omega-3',
        dosageNote: '2 softgels · with lunch',
        slot: 'am',
        colorHex: '#4B7BA6',
        stockLeft: 60,
        frequency: 'daily',
        timesCsv: '13:00',
      ),
      (
        id: '${_demoPrefix}med-magnesium',
        name: 'Magnesium Glycinate',
        dosageNote: '1 tablet · before sleep',
        slot: 'night',
        colorHex: '#7C6BC4',
        stockLeft: 15,
        frequency: 'daily',
        timesCsv: '22:00',
      ),
      (
        id: '${_demoPrefix}med-multivitamin',
        name: 'Multivitamin',
        dosageNote: '1 tablet · with breakfast',
        slot: 'am',
        colorHex: '#3E7C5A',
        stockLeft: null,
        frequency: 'daily',
        timesCsv: '08:00',
      ),
    ];

    // Everything the four above don't reach: the `pm` slot, weekly and
    // alternate-day schedules, multiple dose times, a nearly-empty pack, an
    // exhausted pack, a reminder-enabled row and a discontinued one.
    const medEdgeDefs = [
      (
        id: '${_demoPrefix}med-antihistamine',
        name: 'Antihistamine',
        dosageNote: '1 tablet · after lunch',
        slot: 'pm',
        colorHex: '#3FA6A0',
        stockLeft: 3,
        frequency: 'daily',
        daysCsv: '1,2,3,4,5,6,7',
        timesCsv: '14:00',
        reminder: true,
        active: true,
      ),
      (
        id: '${_demoPrefix}med-b12',
        name: 'Vitamin B12',
        dosageNote: '1 injection · Mondays & Thursdays',
        slot: 'am',
        colorHex: '#B85C6E',
        stockLeft: 8,
        frequency: 'weekly',
        daysCsv: '1,4',
        timesCsv: '09:00',
        reminder: true,
        active: true,
      ),
      (
        id: '${_demoPrefix}med-iron',
        name: 'Iron supplement',
        dosageNote: '1 tablet · alternate days',
        slot: 'pm',
        colorHex: '#C2703D',
        stockLeft: 0,
        frequency: 'alt',
        daysCsv: '1,3,5,7',
        timesCsv: '16:00',
        reminder: false,
        active: true,
      ),
      (
        id: '${_demoPrefix}med-thyroid',
        name: 'Thyroid medication',
        dosageNote: '2 doses · empty stomach and bedtime',
        slot: 'am',
        colorHex: '#7A3D8C',
        stockLeft: 45,
        frequency: 'daily',
        daysCsv: '1,2,3,4,5,6,7',
        timesCsv: '06:30,22:30',
        reminder: true,
        active: true,
      ),
      (
        id: '${_demoPrefix}med-antibiotic',
        name: 'Antibiotic course (finished)',
        dosageNote: '1 capsule · three times daily',
        slot: 'am',
        colorHex: '#5A6B7C',
        stockLeft: 0,
        frequency: 'daily',
        daysCsv: '1,2,3,4,5,6,7',
        timesCsv: '08:00,14:00,20:00',
        reminder: false,
        active: false,
      ),
    ];

    await _db.batch((batch) {
      batch.insertAll(_db.medications, [
        for (final m in medDefs)
          MedicationsCompanion.insert(
            id: Value(m.id),
            name: m.name,
            dosageNote: Value(m.dosageNote),
            slot: Value(m.slot),
            colorHex: Value(m.colorHex),
            stockLeft: Value(m.stockLeft),
            frequency: Value(m.frequency),
            timesCsv: Value(m.timesCsv),
            createdAt: Value(now.subtract(const Duration(days: 90))),
          ),
        for (final m in medEdgeDefs)
          MedicationsCompanion.insert(
            id: Value(m.id),
            name: m.name,
            dosageNote: Value(m.dosageNote),
            slot: Value(m.slot),
            colorHex: Value(m.colorHex),
            stockLeft: Value(m.stockLeft),
            frequency: Value(m.frequency),
            daysCsv: Value(m.daysCsv),
            timesCsv: Value(m.timesCsv),
            reminderEnabled: Value(m.reminder),
            active: Value(m.active),
            createdAt: Value(now.subtract(const Duration(days: 45))),
          ),
      ]);
    });

    // 60 days of history at deliberately different adherence rates, so the
    // screen has a near-perfect row, a patchy one, and one that was stopped
    // partway through. `taken: false` rows record an explicit miss, which is
    // a different thing from no row at all.
    final random = Random(20260830);
    final medLogs = <MedicationLogsCompanion>[];
    final adherence = <String, double>{
      for (final m in medDefs) m.id: 0.85,
      '${_demoPrefix}med-antihistamine': 0.55,
      '${_demoPrefix}med-b12': 0.95,
      '${_demoPrefix}med-iron': 0.40,
      '${_demoPrefix}med-thyroid': 0.99,
      '${_demoPrefix}med-antibiotic': 1.0,
    };
    for (var day = 59; day >= 0; day--) {
      final date = DateTime(now.year, now.month, now.day - day);
      for (final entry in adherence.entries) {
        // The finished antibiotic course only ran 40-33 days ago.
        if (entry.key == '${_demoPrefix}med-antibiotic' &&
            (day > 40 || day < 33)) {
          continue;
        }
        final roll = random.nextDouble();
        if (roll > entry.value && roll > entry.value + 0.08) continue;
        medLogs.add(
          MedicationLogsCompanion.insert(
            id: Value(
              '${_demoPrefix}med-log-${entry.key.split('-').last}-$day',
            ),
            medicationId: entry.key,
            date: DateTime(date.year, date.month, date.day),
            taken: Value(roll <= entry.value),
          ),
        );
      }
    }
    await _db.batch((batch) => batch.insertAll(_db.medicationLogs, medLogs));

    // Workout plan: Mon Push, Wed Pull, Fri Legs, Sat Full Body
    const dayDefs = [
      (
        id: '${_demoPrefix}wd-push',
        weekday: 1,
        label: 'Push Day',
        focus: 'Chest & Triceps',
        start: 420,
        end: 480,
      ),
      (
        id: '${_demoPrefix}wd-pull',
        weekday: 3,
        label: 'Pull Day',
        focus: 'Back & Biceps',
        start: 420,
        end: 480,
      ),
      (
        id: '${_demoPrefix}wd-legs',
        weekday: 5,
        label: 'Leg Day',
        focus: 'Quads & Hamstrings',
        start: 390,
        end: 450,
      ),
      (
        id: '${_demoPrefix}wd-full',
        weekday: 6,
        label: 'Full Body',
        focus: 'Conditioning',
        start: 480,
        end: 540,
      ),
      // Late-evening block — checks a window that doesn't start in the
      // morning, which is what the dashboard's "now" hero reads.
      (
        id: '${_demoPrefix}wd-mobility',
        weekday: 2,
        label: 'Mobility',
        focus: 'Hips & Shoulders',
        start: 1200,
        end: 1245,
      ),
      // Active day with no exercises attached — the empty-plan state.
      (
        id: '${_demoPrefix}wd-cardio',
        weekday: 7,
        label: 'Cardio',
        focus: 'Easy Zone 2',
        start: 450,
        end: 510,
      ),
    ];

    const exerciseDefs = [
      // Push
      (
        id: '${_demoPrefix}ex-bench',
        dayId: '${_demoPrefix}wd-push',
        name: 'Bench Press',
        scheme: '4×10',
        pos: 0,
      ),
      (
        id: '${_demoPrefix}ex-incline',
        dayId: '${_demoPrefix}wd-push',
        name: 'Incline Dumbbell Press',
        scheme: '3×12',
        pos: 1,
      ),
      (
        id: '${_demoPrefix}ex-tricep',
        dayId: '${_demoPrefix}wd-push',
        name: 'Tricep Pushdowns',
        scheme: '3×15',
        pos: 2,
      ),
      (
        id: '${_demoPrefix}ex-lat-raise',
        dayId: '${_demoPrefix}wd-push',
        name: 'Lateral Raises',
        scheme: '4×12',
        pos: 3,
      ),
      // Pull
      (
        id: '${_demoPrefix}ex-pullup',
        dayId: '${_demoPrefix}wd-pull',
        name: 'Pull-ups',
        scheme: '4×8',
        pos: 0,
      ),
      (
        id: '${_demoPrefix}ex-row',
        dayId: '${_demoPrefix}wd-pull',
        name: 'Barbell Row',
        scheme: '4×10',
        pos: 1,
      ),
      (
        id: '${_demoPrefix}ex-curl',
        dayId: '${_demoPrefix}wd-pull',
        name: 'Barbell Curl',
        scheme: '3×12',
        pos: 2,
      ),
      // Legs
      (
        id: '${_demoPrefix}ex-squat',
        dayId: '${_demoPrefix}wd-legs',
        name: 'Back Squat',
        scheme: '4×8',
        pos: 0,
      ),
      (
        id: '${_demoPrefix}ex-rdl',
        dayId: '${_demoPrefix}wd-legs',
        name: 'Romanian Deadlift',
        scheme: '3×10',
        pos: 1,
      ),
      (
        id: '${_demoPrefix}ex-legpress',
        dayId: '${_demoPrefix}wd-legs',
        name: 'Leg Press',
        scheme: '3×15',
        pos: 2,
      ),
      // Full body
      (
        id: '${_demoPrefix}ex-deadlift',
        dayId: '${_demoPrefix}wd-full',
        name: 'Deadlift',
        scheme: '4×6',
        pos: 0,
      ),
      (
        id: '${_demoPrefix}ex-ohp',
        dayId: '${_demoPrefix}wd-full',
        name: 'Overhead Press',
        scheme: '4×8',
        pos: 1,
      ),
      (
        id: '${_demoPrefix}ex-lunge',
        dayId: '${_demoPrefix}wd-full',
        name: 'Walking Lunges',
        scheme: '3×12/leg',
        pos: 2,
      ),
      // Mobility — bodyweight, so logged sets carry zero weight.
      (
        id: '${_demoPrefix}ex-hipopener',
        dayId: '${_demoPrefix}wd-mobility',
        name: 'Couch Stretch',
        scheme: '2×60s',
        pos: 0,
      ),
      (
        id: '${_demoPrefix}ex-shoulder',
        dayId: '${_demoPrefix}wd-mobility',
        name: 'Band Dislocates',
        scheme: '3×15',
        pos: 1,
      ),
    ];

    await _db.batch((batch) {
      batch.insertAll(_db.workoutDays, [
        for (final d in dayDefs)
          WorkoutDaysCompanion.insert(
            id: Value(d.id),
            weekday: d.weekday,
            label: d.label,
            focus: Value(d.focus),
            startMinute: Value(d.start),
            endMinute: Value(d.end),
            createdAt: Value(now.subtract(const Duration(days: 60))),
          ),
        // Retired from the plan but kept for its history.
        WorkoutDaysCompanion.insert(
          id: const Value('${_demoPrefix}wd-retired'),
          weekday: 4,
          label: 'Arms (retired)',
          focus: const Value('Biceps & Triceps'),
          startMinute: const Value(1080),
          endMinute: const Value(1140),
          active: const Value(false),
          createdAt: Value(now.subtract(const Duration(days: 180))),
        ),
      ]);
      batch.insertAll(_db.exercises, [
        for (final e in exerciseDefs)
          ExercisesCompanion.insert(
            id: Value(e.id),
            workoutDayId: e.dayId,
            name: e.name,
            scheme: Value(e.scheme),
            position: Value(e.pos),
          ),
      ]);
    });

    // Twelve weeks of sessions with a slow linear progression, so the
    // history charts have a real trend rather than a flat line. Each
    // session is a weekday-anchored date; weights climb 2.5 kg a fortnight,
    // which is exactly the increment integer grams exist to keep exact.
    // (exercise key, base weight in grams, per-week gain, sets, reps)
    const lifts = [
      ('bench', 60000, 1250, 4, 10),
      ('incline', 24000, 500, 3, 12),
      ('tricep', 22500, 375, 3, 15),
      ('lat-raise', 8000, 250, 4, 12),
      ('pullup', 0, 0, 4, 8),
      ('row', 50000, 1000, 4, 10),
      ('curl', 20000, 500, 3, 12),
      ('squat', 80000, 1875, 4, 8),
      ('rdl', 70000, 1250, 3, 10),
      ('legpress', 140000, 2500, 3, 15),
      ('deadlift', 100000, 2000, 4, 6),
      ('ohp', 35000, 625, 4, 8),
      ('lunge', 16000, 250, 3, 12),
      // Bodyweight mobility work — zero grams throughout.
      ('hipopener', 0, 0, 2, 1),
      ('shoulder', 0, 0, 3, 15),
    ];
    // Which day each lift belongs to, so sessions land on the right weekday.
    const liftWeekday = {
      'bench': 1, 'incline': 1, 'tricep': 1, 'lat-raise': 1,
      'pullup': 3, 'row': 3, 'curl': 3,
      'squat': 5, 'rdl': 5, 'legpress': 5,
      'deadlift': 6, 'ohp': 6, 'lunge': 6,
      'hipopener': 2, 'shoulder': 2,
    };

    final setRandom = Random(20260902);
    final workoutLogs = <WorkoutLogsCompanion>[];
    final setLogs = <ExerciseSetLogsCompanion>[];
    final today = dateOnly(now);

    for (var week = 0; week < 12; week++) {
      for (final lift in lifts) {
        final key = lift.$1;
        final weekday = liftWeekday[key]!;
        // Most recent occurrence of that weekday, then step back by weeks.
        var day = today.subtract(Duration(days: (today.weekday - weekday) % 7));
        day = day.subtract(Duration(days: 7 * week));
        if (day.isAfter(today)) day = day.subtract(const Duration(days: 7));

        // A skipped week, so completion isn't uniformly perfect.
        if (week == 4 && (key == 'squat' || key == 'rdl')) continue;

        workoutLogs.add(
          WorkoutLogsCompanion.insert(
            id: Value('${_demoPrefix}wl-$key-w$week'),
            exerciseId: '$_demoPrefix' 'ex-$key',
            date: day,
            completed: const Value(true),
          ),
        );

        // Newer weeks are heavier: week 0 is today, week 11 is oldest.
        final weeksElapsed = 11 - week;
        final weight = lift.$2 + lift.$3 * weeksElapsed;
        for (var s = 1; s <= lift.$4; s++) {
          setLogs.add(
            ExerciseSetLogsCompanion.insert(
              id: Value('${_demoPrefix}sl-$key-w$week-s$s'),
              exerciseId: '$_demoPrefix' 'ex-$key',
              date: day,
              setNumber: s,
              // Reps tail off on the last set, as they do in practice.
              reps: Value(
                s == lift.$4 ? max(1, lift.$5 - 2 - setRandom.nextInt(2)) : lift.$5,
              ),
              weightGrams: Value(weight),
              createdAt: Value(day),
            ),
          );
        }
      }
    }

    await _db.batch((batch) {
      batch.insertAll(_db.workoutLogs, workoutLogs);
      batch.insertAll(_db.exerciseSetLogs, setLogs);
    });
  }

  Future<void> _insertLearnData(DateTime now) async {
    const bookDefs = [
      (
        id: '${_demoPrefix}book-flutter',
        name: 'Flutter & Dart Deep Dive',
        colorHex: '#4B7BA6',
      ),
      (
        id: '${_demoPrefix}book-finance',
        name: 'Personal Finance Fundamentals',
        colorHex: '#C49A3D',
      ),
      (
        id: '${_demoPrefix}book-psychology',
        name: 'Behavioural Psychology',
        colorHex: '#7C6BC4',
      ),
      (
        id: '${_demoPrefix}book-productivity',
        name: 'Productivity & Systems',
        colorHex: '#3E7C5A',
      ),
      // Created but never written into — the 0% / empty-book state.
      (
        id: '${_demoPrefix}book-empty',
        name: 'System Design (not started)',
        colorHex: '#5A6B7C',
      ),
    ];

    await _db.batch((batch) {
      batch.insertAll(_db.learnBooks, [
        for (final b in bookDefs)
          LearnBooksCompanion.insert(
            id: Value(b.id),
            name: b.name,
            colorHex: Value(b.colorHex),
            createdAt: Value(now.subtract(const Duration(days: 120))),
          ),
        // Archived — should drop out of the active list but keep its notes.
        LearnBooksCompanion.insert(
          id: const Value('${_demoPrefix}book-archived'),
          name: 'Old Certification Prep',
          colorHex: const Value('#7A3D8C'),
          archived: const Value(true),
          createdAt: Value(now.subtract(const Duration(days: 400))),
        ),
      ]);
    });

    final noteDefs = [
      // Flutter book
      (
        id: '${_demoPrefix}ln-riverpod-providers',
        bookId: '${_demoPrefix}book-flutter',
        title: 'Riverpod provider types',
        excerpt: 'Provider, NotifierProvider, StreamProvider and when to use each.',
        prompt: 'What is the difference between Provider and NotifierProvider?',
        tags: 'state,riverpod',
        minutes: 5,
        starred: true,
        daysAgo: 10,
        reviewDue: 3,
      ),
      (
        id: '${_demoPrefix}ln-widget-lifecycle',
        bookId: '${_demoPrefix}book-flutter',
        title: 'Widget lifecycle methods',
        excerpt: 'initState, didChangeDependencies, didUpdateWidget and dispose.',
        prompt: 'When does didChangeDependencies fire vs initState?',
        tags: 'widgets,lifecycle',
        minutes: 4,
        starred: false,
        daysAgo: 20,
        // Negative: the review is already overdue.
        reviewDue: -4,
      ),
      (
        id: '${_demoPrefix}ln-slivers',
        bookId: '${_demoPrefix}book-flutter',
        title: 'Slivers and custom scroll views',
        excerpt: 'SliverList, SliverGrid, SliverAppBar — composing scrollable layouts.',
        prompt: 'When should you prefer a SliverGrid over a GridView?',
        tags: 'layout,slivers',
        minutes: 6,
        starred: false,
        daysAgo: 5,
        reviewDue: 7,
      ),
      // Finance book
      (
        id: '${_demoPrefix}ln-compound-interest',
        bookId: '${_demoPrefix}book-finance',
        title: 'Compound interest',
        excerpt: 'The eighth wonder of the world — time, rate and frequency interact.',
        prompt: 'How does compounding frequency affect the final amount?',
        tags: 'investing,basics',
        minutes: 3,
        starred: true,
        daysAgo: 30,
        reviewDue: null,
      ),
      (
        id: '${_demoPrefix}ln-50-30-20',
        bookId: '${_demoPrefix}book-finance',
        title: '50/30/20 budgeting rule',
        excerpt: '50% needs, 30% wants, 20% savings — a simple allocation framework.',
        prompt: 'What category does an EMI payment fall under?',
        tags: 'budgeting,framework',
        minutes: 2,
        starred: false,
        daysAgo: 25,
        reviewDue: 2,
      ),
      (
        id: '${_demoPrefix}ln-emergency-fund',
        bookId: '${_demoPrefix}book-finance',
        title: 'Emergency fund sizing',
        excerpt: '3–6 months of essential expenses in a liquid account.',
        prompt: 'Why keep an emergency fund separate from investments?',
        tags: 'savings,risk',
        minutes: 3,
        starred: false,
        daysAgo: 18,
        reviewDue: -12,
      ),
      // Psychology book
      (
        id: '${_demoPrefix}ln-habit-loop',
        bookId: '${_demoPrefix}book-psychology',
        title: 'The habit loop',
        excerpt: 'Cue → Routine → Reward — how automatic behaviours form.',
        prompt: 'How can you change the routine while keeping the cue and reward?',
        tags: 'habits,behaviour',
        minutes: 4,
        starred: true,
        daysAgo: 14,
        reviewDue: 1,
      ),
      (
        id: '${_demoPrefix}ln-loss-aversion',
        bookId: '${_demoPrefix}book-psychology',
        title: 'Loss aversion',
        excerpt: 'Losses loom about twice as large as equivalent gains.',
        prompt: 'How does loss aversion affect financial decision-making?',
        tags: 'cognitive-bias,finance',
        minutes: 3,
        starred: false,
        daysAgo: 8,
        reviewDue: null,
      ),
      // Productivity book
      (
        id: '${_demoPrefix}ln-time-blocking',
        bookId: '${_demoPrefix}book-productivity',
        title: 'Time blocking',
        excerpt: 'Assign every hour a job before the day starts.',
        prompt: 'What is the difference between time blocking and a to-do list?',
        tags: 'planning,focus',
        minutes: 3,
        starred: false,
        daysAgo: 12,
        reviewDue: 5,
      ),
      (
        id: '${_demoPrefix}ln-two-minute',
        bookId: '${_demoPrefix}book-productivity',
        title: 'Two-minute rule',
        excerpt: 'If an action takes less than two minutes, do it now.',
        prompt: 'What problem does the two-minute rule solve?',
        tags: 'gtd,action',
        minutes: 2,
        starred: true,
        daysAgo: 6,
        reviewDue: null,
      ),
    ];

    // Every note gets all three body treatments the reader renders, so no
    // note exercises only the plain-prose path.
    String body(String intro, String quote, String code) => jsonEncode([
      {'t': 'p', 'text': intro},
      {'t': 'quote', 'text': quote},
      {'t': 'p', 'text': 'In practice this shows up whenever the same '
          'decision has to be made more than once, which is why it is worth '
          'writing down rather than re-deriving each time.'},
      {'t': 'code', 'text': code},
      {'t': 'p', 'text': 'Revisit this before the next review to check the '
          'summary above still matches how you would explain it out loud.'},
    ]);

    await _db.batch((batch) {
      batch.insertAll(_db.learnNotes, [
        for (final n in noteDefs)
          LearnNotesCompanion.insert(
            id: Value(n.id),
            bookId: n.bookId,
            title: n.title,
            excerpt: Value(n.excerpt),
            bodyJson: Value(
              body(
                n.excerpt,
                'The point is not to memorise the definition but to recognise '
                    'the situation it applies to.',
                '// ${n.title}\n// ${n.tags.split(',').join(' · ')}\n'
                    'final result = apply(${n.title.split(' ').first.toLowerCase()});',
              ),
            ),
            prompt: Value(n.prompt),
            tagsCsv: Value(n.tags),
            minutes: Value(n.minutes),
            starred: Value(n.starred),
            reviewDueAt: Value(
              n.reviewDue != null
                  ? DateTime(now.year, now.month, now.day + n.reviewDue!)
                  : null,
            ),
            lastReviewedAt: Value(
              now.subtract(Duration(days: n.daysAgo)),
            ),
            createdAt: Value(now.subtract(Duration(days: n.daysAgo + 5))),
            updatedAt: Value(now.subtract(Duration(days: n.daysAgo))),
          ),

        // Never reviewed — lastReviewedAt null is what the book's progress
        // percentage counts against, so these hold the number below 100%.
        LearnNotesCompanion.insert(
          id: const Value('${_demoPrefix}ln-unreviewed-isolates'),
          bookId: '${_demoPrefix}book-flutter',
          title: 'Isolates and compute()',
          excerpt: const Value('Moving CPU-bound work off the UI isolate.'),
          bodyJson: Value(
            body(
              'Dart is single-threaded per isolate, so a long synchronous '
                  'computation blocks the frame loop.',
              'If it takes longer than a frame, it does not belong on the UI '
                  'isolate.',
              'final parsed = await compute(parseBigJson, raw);',
            ),
          ),
          prompt: const Value('When is compute() worth the copying overhead?'),
          tagsCsv: const Value('performance,concurrency'),
          minutes: const Value(7),
          createdAt: Value(now.subtract(const Duration(days: 4))),
          updatedAt: Value(now.subtract(const Duration(days: 4))),
        ),
        LearnNotesCompanion.insert(
          id: const Value('${_demoPrefix}ln-unreviewed-tax'),
          bookId: '${_demoPrefix}book-finance',
          title: 'Old vs new tax regime',
          excerpt: const Value('Which deductions survive, and the break-even income.'),
          prompt: const Value('At what income do the two regimes converge?'),
          tagsCsv: const Value('tax,planning'),
          minutes: const Value(8),
          starred: const Value(true),
          // Due today — the boundary case between upcoming and overdue.
          reviewDueAt: Value(DateTime(now.year, now.month, now.day)),
          createdAt: Value(now.subtract(const Duration(days: 9))),
          updatedAt: Value(now.subtract(const Duration(days: 9))),
        ),
        // Minimal row: empty body, no prompt, no tags — everything optional
        // left at its default.
        LearnNotesCompanion.insert(
          id: const Value('${_demoPrefix}ln-bare'),
          bookId: '${_demoPrefix}book-productivity',
          title: 'Inbox zero — revisit later',
          createdAt: Value(now.subtract(const Duration(days: 1))),
          updatedAt: Value(now.subtract(const Duration(days: 1))),
        ),
        // Notes under the archived book.
        LearnNotesCompanion.insert(
          id: const Value('${_demoPrefix}ln-archived-networking'),
          bookId: '${_demoPrefix}book-archived',
          title: 'TCP handshake',
          excerpt: const Value('SYN, SYN-ACK, ACK — and why it costs a round trip.'),
          prompt: const Value('Why does TLS 1.3 need fewer round trips?'),
          tagsCsv: const Value('networking,certification'),
          minutes: const Value(5),
          lastReviewedAt: Value(now.subtract(const Duration(days: 380))),
          createdAt: Value(now.subtract(const Duration(days: 400))),
          updatedAt: Value(now.subtract(const Duration(days: 380))),
        ),
        // Long read — the upper end of the estimated-minutes display.
        LearnNotesCompanion.insert(
          id: const Value('${_demoPrefix}ln-long-read'),
          bookId: '${_demoPrefix}book-psychology',
          title: 'Dual process theory in full',
          excerpt: const Value(
            'System 1 and System 2 across attention, memory and judgement.',
          ),
          bodyJson: Value(
            jsonEncode([
              for (var i = 0; i < 12; i++)
                {
                  't': i % 4 == 3 ? 'quote' : 'p',
                  'text':
                      'Part ${i + 1}. Fast, automatic processing handles the '
                      'familiar case without conscious effort, while the '
                      'slower deliberate system is recruited only when the '
                      'first one signals that something does not fit.',
                },
            ]),
          ),
          prompt: const Value(
            'What conditions reliably recruit System 2 over System 1?',
          ),
          tagsCsv: const Value('cognition,attention,judgement'),
          minutes: const Value(24),
          starred: const Value(true),
          reviewDueAt: Value(
            DateTime(now.year, now.month, now.day + 21),
          ),
          lastReviewedAt: Value(now.subtract(const Duration(days: 40))),
          createdAt: Value(now.subtract(const Duration(days: 70))),
          updatedAt: Value(now.subtract(const Duration(days: 40))),
        ),
      ]);
    });
  }

  Future<void> _insertNotes(DateTime now, Map<String, String> folderIds) async {
    const content = [
      (
        'Annual priorities',
        'Health, family, focused work, and financial resilience.',
      ),
      (
        'Books to read',
        'A mix of biographies, design, psychology, and personal finance.',
      ),
      (
        'Meal ideas',
        'Vegetable pulao, lentil soup, grilled paneer, overnight oats.',
      ),
      (
        'Travel checklist',
        'Tickets, accommodation, documents, medicine, chargers.',
      ),
      (
        'Monthly reflection',
        'What went well, what felt difficult, and what to change.',
      ),
      ('Gift ideas', 'Keep a running list for family and close friends.'),
      (
        'Home improvements',
        'Better lighting, storage shelves, and desk organisation.',
      ),
      (
        'Learning plan',
        'Two focused sessions each week and one monthly project.',
      ),
      ('Emergency contacts', 'Maintain an offline list of essential contacts.'),
      ('Ideas inbox', 'A place to capture ideas before organising them.'),
    ];
    // Rotate the first nine through the three notes folders; the rest stay
    // unfiled so both the folder and the loose-notes paths have content.
    const folderRotation = ['work', 'personal', 'ideas'];

    await _db.batch((batch) {
      batch.insertAll(_db.notes, [
        for (var i = 0; i < content.length; i++)
          NotesCompanion.insert(
            id: Value('$_demoPrefix note-$i'.replaceAll(' ', '')),
            title: content[i].$1,
            body: Value(content[i].$2),
            folderId: Value(
              i < 9 ? folderIds[folderRotation[i % 3]] : null,
            ),
            createdAt: Value(now.subtract(Duration(days: 25 * (i + 1)))),
            updatedAt: Value(now.subtract(Duration(days: 7 * i))),
          ),
        // Empty body — the list has to render a note with no preview text.
        NotesCompanion.insert(
          id: const Value('${_demoPrefix}note-empty'),
          title: 'Untitled thought',
          createdAt: Value(now.subtract(const Duration(days: 2))),
          updatedAt: Value(now.subtract(const Duration(days: 2))),
        ),
        // Long body — scrolling, wrapping and preview truncation.
        NotesCompanion.insert(
          id: const Value('${_demoPrefix}note-long'),
          title: 'Apartment renovation brief',
          body: Value(
            List.generate(
              14,
              (i) =>
                  'Section ${i + 1}. Scope, budget and sequencing for this part '
                  'of the renovation, including who is responsible, what has to '
                  'be finished before it can start, and the rough cost estimate '
                  'agreed with the contractor during the last site visit.',
            ).join('\n\n'),
          ),
          folderId: Value(folderIds['personal']),
          createdAt: Value(now.subtract(const Duration(days: 60))),
          updatedAt: Value(now.subtract(const Duration(hours: 5))),
        ),
        // Edited today — sorts to the top of a recently-updated list.
        NotesCompanion.insert(
          id: const Value('${_demoPrefix}note-today'),
          title: 'Standup talking points',
          body: const Value(
            'Shipped the document organiser. Blocked on the release keystore. '
            'Next: data export.',
          ),
          folderId: Value(folderIds['work']),
          createdAt: Value(now.subtract(const Duration(days: 1))),
          updatedAt: Value(now),
        ),
      ]);
    });
  }
}

final demoDataServiceProvider = Provider<DemoDataService>(
  (ref) => DemoDataService(ref.watch(appDatabaseProvider)),
);
