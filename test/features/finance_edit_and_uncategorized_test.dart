import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart';
import 'package:life_manager/features/spend_analyzer/application/spend_analyzer_providers.dart';

class _FakeNotifications extends NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> scheduleBillReminder({
    required String billId,
    required String title,
    required DateTime reminderTime,
    ReminderMode mode = ReminderMode.notification,
  }) async {}
  @override
  Future<void> cancelBillReminder(String billId) async {}
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(_FakeNotifications()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<String> seedAccount() async {
    final account = await db
        .into(db.accounts)
        .insertReturning(
          AccountsCompanion.insert(name: 'Wallet', type: 'cash'),
        );
    return account.id;
  }

  group('bills can be edited', () {
    test('every field round-trips and history is untouched', () async {
      final accountId = await seedAccount();
      final controller = container.read(financeControllerProvider);

      await controller.addBill(
        name: 'Rent',
        accountId: accountId,
        amountMinor: 2200000,
        dueDate: DateTime(2026, 10, 1),
        frequency: 'monthly',
      );
      var bill = await db.select(db.bills).getSingle();

      // A payment before the edit: its transaction must survive.
      await controller.markBillPaid(bill, accountId: accountId);
      final paidCount = (await db.select(db.transactions).get()).length;
      expect(paidCount, 1);
      bill = await db.select(db.bills).getSingle();

      await controller.updateBill(
        id: bill.id,
        name: 'Rent — new flat',
        accountId: accountId,
        categoryId: null,
        amountMinor: 2450000,
        dueDate: DateTime(2026, 12, 5),
        frequency: 'yearly',
        reminderEnabled: false,
        reminderMode: ReminderMode.alarm,
        reminderDaysBefore: 3,
      );

      final updated = await db.select(db.bills).getSingle();
      expect(updated.id, bill.id, reason: 'edited in place, not replaced');
      expect(updated.name, 'Rent — new flat');
      expect(updated.amountMinor, 2450000);
      expect(updated.dueDate, DateTime(2026, 12, 5));
      expect(updated.frequency, 'yearly');
      expect(updated.reminderEnabled, isFalse);
      expect(updated.reminderDaysBefore, 3);
      expect(updated.reminderMode, ReminderMode.alarm.storageValue);
      expect(
        (await db.select(db.transactions).get()).length,
        paidCount,
        reason: 'editing a bill must not touch what was already paid',
      );
    });
  });

  group('recurring transactions can be edited', () {
    test('moving the cadence resets the next due date, keeping history',
        () async {
      final accountId = await seedAccount();
      final controller = container.read(financeControllerProvider);

      // Starts today, so one occurrence generates immediately.
      await controller.addRecurringTransaction(
        accountId: accountId,
        merchant: 'Gym',
        amountMinor: -150000,
        frequency: 'monthly',
        startDate: DateTime.now(),
      );
      final generated = (await db.select(db.transactions).get()).length;
      expect(generated, greaterThan(0));

      final schedule = await db.select(db.recurringTransactions).getSingle();
      final future = DateTime.now().add(const Duration(days: 40));

      await controller.updateRecurringTransaction(
        existing: schedule,
        accountId: accountId,
        merchant: 'Gym — annual',
        amountMinor: -1200000,
        frequency: 'yearly',
        startDate: future,
      );

      final updated = await db.select(db.recurringTransactions).getSingle();
      expect(updated.id, schedule.id);
      expect(updated.merchant, 'Gym — annual');
      expect(updated.amountMinor, -1200000);
      expect(updated.frequency, 'yearly');
      expect(
        updated.nextDueDate.difference(future).inDays.abs(),
        lessThanOrEqualTo(1),
        reason: 'cadence moved, so the schedule should fire from the new date',
      );
      expect(
        (await db.select(db.transactions).get()).length,
        generated,
        reason: 'a future start date must not generate anything yet',
      );
    });

    test('editing only the name leaves the schedule where it was', () async {
      final accountId = await seedAccount();
      final controller = container.read(financeControllerProvider);
      await controller.addRecurringTransaction(
        accountId: accountId,
        merchant: 'Netflix',
        amountMinor: -49900,
        frequency: 'monthly',
        startDate: DateTime.now(),
      );
      final schedule = await db.select(db.recurringTransactions).getSingle();

      await controller.updateRecurringTransaction(
        existing: schedule,
        accountId: accountId,
        merchant: 'Netflix Premium',
        amountMinor: -69900,
        frequency: schedule.frequency,
        startDate: schedule.nextDueDate,
      );

      final updated = await db.select(db.recurringTransactions).getSingle();
      expect(updated.merchant, 'Netflix Premium');
      expect(updated.nextDueDate, schedule.nextDueDate);
    });
  });

  group('uncategorised spend reaches the analyzer', () {
    test('a bill paid without a category becomes its own slice', () async {
      final accountId = await seedAccount();
      final controller = container.read(financeControllerProvider);

      final category = await db
          .into(db.categories)
          .insertReturning(
            CategoriesCompanion.insert(name: 'Dining', colorHex: '#2E9E63'),
          );

      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: accountId,
              merchant: 'Cafe',
              amountMinor: -30000,
              date: DateTime.now(),
              categoryId: Value(category.id),
            ),
          );

      // The case that used to vanish: a bill with no category.
      await controller.addBill(
        name: 'Broadband',
        accountId: accountId,
        amountMinor: 70000,
        dueDate: DateTime.now(),
      );
      final bill = await db.select(db.bills).getSingle();
      await controller.markBillPaid(bill, accountId: accountId);

      // Hold the streams open while the derived providers settle.
      final subs = [
        container.listen(transactionsProvider, (_, _) {}),
        container.listen(categoriesProvider, (_, _) {}),
      ];
      await container.read(transactionsProvider.future);
      await container.read(categoriesProvider.future);

      final breakdown = container.read(categoryBreakdownProvider);
      final uncategorized = breakdown.where((e) => e.isUncategorized);

      expect(uncategorized, hasLength(1), reason: 'the bill must be visible');
      expect(uncategorized.single.totalMinor, 70000);
      expect(uncategorized.single.label, 'Uncategorized');
      expect(
        breakdown.last.isUncategorized,
        isTrue,
        reason: 'the remainder sorts last',
      );

      // Shares add up, which they did not while uncategorised spend was
      // dropped from the denominator.
      final shareTotal = breakdown.fold<double>(0, (sum, e) => sum + e.share);
      expect(shareTotal, closeTo(1.0, 0.0001));

      final total = breakdown.fold<int>(0, (sum, e) => sum + e.totalMinor);
      expect(
        total,
        container.read(monthExpenseTotalMinorProvider),
        reason: 'the donut must agree with the headline figure',
      );

      for (final s in subs) {
        s.close();
      }
    });
  });
}
