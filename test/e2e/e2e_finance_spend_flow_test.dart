import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/ai_analyser/application/ai_analyser_providers.dart';
import 'package:life_manager/features/ai_analyser/data/insights_repository.dart';
import 'package:life_manager/features/ai_analyser/domain/analytics_rule_engine.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/finance/domain/net_worth_point.dart';
import 'package:life_manager/features/goals/domain/goal_progress.dart';
import 'package:life_manager/features/habits/domain/habit_progress.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late FileStorageService storage;
  late FinanceRepository financeRepo;
  late InsightsRepository insightsRepo;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('e2e_finance_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    storage = FileStorageService();
    financeRepo = FinanceRepository(db, storage);
    insightsRepo = InsightsRepository(db);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        financeRepositoryProvider.overrideWithValue(financeRepo),
        insightsRepositoryProvider.overrideWithValue(insightsRepo),
      ],
    );

    // Initialize default categories and account types
    await financeRepo.ensureDefaultCategories();
    await financeRepo.ensureDefaultAccountTypes();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('E2E Financial Life Journey & Edge Cases', () {
    test('complete finance lifecycle: accounts -> transactions -> budgets -> analytics -> AI insights', () async {
      // 1. Create accounts: Checking, Savings, Credit Card
      final checking = await db.into(db.accounts).insertReturning(
        AccountsCompanion.insert(
          name: 'Primary Checking',
          type: 'checking',
          balanceMinor: const Value(1000000), // ₹10,000.00
        ),
      );
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          name: 'Emergency Savings',
          type: 'savings',
          balanceMinor: const Value(5000000), // ₹50,000.00
        ),
      );

      final categories = await db.select(db.categories).get();
      final diningCat = categories.firstWhere((c) => c.name == 'Dining');
      final incomeCat = categories.firstWhere((c) => c.kind == 'income');

      final now = DateTime(2026, 8, 15, 14, 30);

      // 2. Set monthly budget for Dining (Limit: ₹2,000.00 = 200000 minor units)
      final diningBudget = await db.into(db.budgets).insertReturning(
        BudgetsCompanion.insert(
          categoryId: diningCat.id,
          limitMinor: 200000,
          period: const Value('monthly'),
          startDate: DateTime(2026, 8, 1),
        ),
      );

      // 3. Add transactions: Under budget, edge cases (income & expense)
      // Transaction 1: Regular dining expense ₹800
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: checking.id,
          categoryId: Value(diningCat.id),
          merchant: 'Restaurant Alpha',
          amountMinor: -80000,
          date: now,
        ),
      );

      // Transaction 2: Income ₹25,000 into Checking
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: checking.id,
          categoryId: Value(incomeCat.id),
          merchant: 'Monthly Salary',
          amountMinor: 2500000,
          date: now.subtract(const Duration(days: 2)),
        ),
      );

      // Verify intermediate budget progress
      final allBudgets = await db.select(db.budgets).get();
      final allTxns = await db.select(db.transactions).get();
      final budgetProgressList = progressFor(
        allBudgetVersions: allBudgets,
        categories: categories,
        transactions: allTxns,
        month: now,
      );

      expect(budgetProgressList, hasLength(1));
      expect(budgetProgressList.first.spentMinor, 80000);
      expect(budgetProgressList.first.isOver, isFalse);
      expect(budgetProgressList.first.ratio, closeTo(0.4, 0.01));

      // 4. Overspend edge case: Add another large dining expense ₹1,800 -> Total Dining: ₹2,600 (Limit: ₹2,000 -> 30% over)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: checking.id,
          categoryId: Value(diningCat.id),
          merchant: 'Fine Dining Bistro',
          amountMinor: -180000,
          date: now,
        ),
      );

      final updatedTxns = await db.select(db.transactions).get();
      final overspentBudgets = progressFor(
        allBudgetVersions: allBudgets,
        categories: categories,
        transactions: updatedTxns,
        month: now,
      );

      expect(overspentBudgets.first.spentMinor, 260000);
      expect(overspentBudgets.first.isOver, isTrue);

      // 5. Run AI Analyser Rule Engine with the overspent budget
      final drafts = computeInsights(
        budgets: overspentBudgets,
        habits: <HabitProgress>[],
        tasksCompletedThisWeek: 0,
        tasksCompletedLastWeek: 0,
        goals: <GoalWithLinks>[],
        bills: <Bill>[],
        netWorthTrend: <NetWorthPoint>[],
        milestonesByGoal: {},
        now: now,
      );

      expect(drafts.any((d) => d.type == 'overspend' && d.relatedEntityId == diningBudget.id), isTrue);
      final overspendDraft = drafts.firstWhere((d) => d.type == 'overspend');
      expect(overspendDraft.severity, 'critical'); // 30% over >= 20% threshold

      // 6. Reconcile insights with InsightsRepository
      await insightsRepo.reconcile(drafts);
      final activeInsights = await insightsRepo.watchActiveInsights().first;
      expect(activeInsights, hasLength(1));
      expect(activeInsights.first.relatedEntityId, diningBudget.id);

      // 7. Dismiss the insight and verify it remains dismissed on next reconciliation
      await insightsRepo.dismiss(activeInsights.first.id);
      final activeAfterDismiss = await insightsRepo.watchActiveInsights().first;
      expect(activeAfterDismiss, isEmpty);

      // Re-run reconcile with same draft -> dismissed insight must NOT reappear
      await insightsRepo.reconcile(drafts);
      final activeAfterReReconcile = await insightsRepo.watchActiveInsights().first;
      expect(activeAfterReReconcile, isEmpty);

      // 8. Add Bill due soon edge case
      final bill = await db.into(db.bills).insertReturning(
        BillsCompanion.insert(
          name: 'Broadband Fiber',
          amountMinor: 99900,
          dueDate: now.add(const Duration(days: 2)), // Due in 2 days (<= 3 days threshold)
        ),
      );

      final billDrafts = computeInsights(
        budgets: overspentBudgets,
        habits: <HabitProgress>[],
        tasksCompletedThisWeek: 0,
        tasksCompletedLastWeek: 0,
        goals: <GoalWithLinks>[],
        bills: [bill],
        netWorthTrend: <NetWorthPoint>[],
        milestonesByGoal: {},
        now: now,
      );

      final billDueInsight = billDrafts.firstWhere((d) => d.type == 'bill_due_soon');
      expect(billDueInsight.severity, 'critical');
      expect(billDueInsight.relatedEntityId, bill.id);
    });

    test('finance boundary edge cases: zero amount transactions, large values, cross-month date filtering', () async {
      final account = await db.into(db.accounts).insertReturning(
        AccountsCompanion.insert(
          name: 'Edge Test Account',
          type: 'checking',
          balanceMinor: const Value(0),
        ),
      );

      final categories = await db.select(db.categories).get();
      final transportCat = categories.firstWhere((c) => c.name == 'Transport');

      // Edge case 1: ₹0.00 zero-amount transaction
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          categoryId: Value(transportCat.id),
          merchant: 'Free Transit Pass',
          amountMinor: 0,
          date: DateTime(2026, 8, 1),
        ),
      );

      // Edge case 2: Very large transaction (₹10,00,000 = 100,000,000 paise)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          categoryId: Value(transportCat.id),
          merchant: 'Vehicle Purchase',
          amountMinor: -100000000,
          date: DateTime(2026, 8, 2),
        ),
      );

      // Edge case 3: Transaction in previous month (July 2026)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          categoryId: Value(transportCat.id),
          merchant: 'July Fuel',
          amountMinor: -500000,
          date: DateTime(2026, 7, 31, 23, 59),
        ),
      );

      // Set budget for Transport in August
      await db.into(db.budgets).insert(
        BudgetsCompanion.insert(
          categoryId: transportCat.id,
          limitMinor: 200000000, // ₹20,00,000
          period: const Value('monthly'),
          startDate: DateTime(2026, 8, 1),
        ),
      );

      final allBudgets = await db.select(db.budgets).get();
      final allTxns = await db.select(db.transactions).get();
      final budgets = progressFor(
        allBudgetVersions: allBudgets,
        categories: categories,
        transactions: allTxns,
        month: DateTime(2026, 8, 15),
      );

      expect(budgets, hasLength(1));
      // Spent should include August txns (100000000 paise) but NOT July txn
      expect(budgets.first.spentMinor, 100000000);
      expect(budgets.first.isOver, isFalse);
    });
  });
}
