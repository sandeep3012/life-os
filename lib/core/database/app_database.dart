import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import 'tables/calendar_tables.dart';
import 'tables/categories_table.dart';
import 'tables/documents_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/folders_table.dart';
import 'tables/goals_tables.dart';
import 'tables/habits_tables.dart';
import 'tables/insights_table.dart';
import 'tables/notes_tables.dart';
import 'tables/settings_table.dart';
import 'tables/tasks_tables.dart';

part 'app_database.g.dart';

/// Single on-device SQLite database backing every module. Cross-module
/// screens (Calendar, AI Analyser) rely on being able to join across these
/// tables directly, which is the main reason this app uses one relational
/// database instead of a per-feature store.
@DriftDatabase(
  tables: [
    Categories,
    Tags,
    EntityTags,
    AccountTypes,
    Accounts,
    Transactions,
    RecurringTransactions,
    Bills,
    Budgets,
    Habits,
    HabitLogs,
    Tasks,
    Subtasks,
    Goals,
    GoalLinks,
    Events,
    Folders,
    Notes,
    Documents,
    Insights,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // v1 -> v2: every table gained an explicit `PRIMARY KEY` on `id` (it
        // was previously just a plain unique-by-convention text column,
        // which is why `insertOnConflictUpdate` — used by the backup/restore
        // feature — failed with "Table has no primary key"). No app had
        // shipped with v1 data yet, so a full recreate was the simplest
        // correct fix rather than a per-table rebuild.
        for (final table in allTables) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
        return;
      }
      if (from < 3) {
        // v2 -> v3: accounts gained `isActive`, for deactivating accounts
        // that can't be safely hard-deleted (still referenced by
        // transactions/goal links) — purely additive, no data loss.
        await m.addColumn(accounts, accounts.isActive);
      }
      if (from < 4) {
        // v3 -> v4: budgets became version-per-month (`effectiveMonth`,
        // `active`) instead of one mutable row per category, so editing a
        // limit no longer rewrites history. Existing rows are backfilled to
        // their `startDate`'s month so they keep applying from whenever they
        // were originally created.
        await m.addColumn(budgets, budgets.effectiveMonth);
        await m.addColumn(budgets, budgets.active);
        await m.database.customStatement(
          "UPDATE budgets SET effective_month = date(start_date, 'start of month')",
        );
      }
      if (from < 5) {
        // v4 -> v5: account "type" and transaction "category" become
        // user-manageable (`AccountTypes` table) plus a payment-mode tag on
        // transactions. `AccountTypes` is seeded lazily on next app start
        // (`ensureDefaultAccountTypes`), same as `Categories` always has
        // been — no data to backfill here since `Accounts.type` already
        // stores the matching name string and needs no rewrite.
        await m.createTable(accountTypes);
        await m.addColumn(transactions, transactions.paymentMode);
      }
      if (from < 6) {
        // v5 -> v6: per-item reminder toggles. Tasks default `true` (an
        // existing task with a due date already got a reminder, so this
        // preserves that behavior); habits default `false` (opt-in — there's
        // no due-date-like signal implying a reminder was wanted).
        await m.addColumn(tasks, tasks.reminderEnabled);
        await m.addColumn(habits, habits.reminderEnabled);
        await m.addColumn(habits, habits.reminderHour);
        await m.addColumn(habits, habits.reminderMinute);
      }
      if (from < 7) {
        // v6 -> v7: reminders can be delivered as a plain notification or
        // an alarm-style one (loud, bypasses silent mode). Existing rows
        // default to 'notification', preserving current behavior.
        await m.addColumn(tasks, tasks.reminderMode);
        await m.addColumn(habits, habits.reminderMode);
      }
      if (from < 8) {
        // v7 -> v8: recurring transactions (subscriptions, rent, EMIs) that
        // auto-generate real Transactions rows on a schedule.
        await m.createTable(recurringTransactions);
      }
      if (from < 9) {
        // v8 -> v9: bill due-date tracking with its own reminder, separate
        // from recurring transactions since a bill needs manual confirm-
        // and-pay rather than silent auto-entry.
        await m.createTable(bills);
      }
      if (from < 10) {
        // v9 -> v10: a transaction can carry a receipt photo, filed as a
        // Document like any other imported file.
        await m.addColumn(transactions, transactions.receiptDocumentId);
      }
      if (from < 11) {
        // v10 -> v11: recurring events (simple daily/weekly/monthly/yearly,
        // upfront-generated occurrences) and per-event reminders, mirroring
        // Bills' reminder shape but offset in minutes-before-start since
        // events are time-of-day scheduled rather than date-only.
        await m.addColumn(events, events.frequency);
        await m.addColumn(events, events.recurrenceEndDate);
        await m.addColumn(events, events.recurrenceId);
        await m.addColumn(events, events.recurrenceNextGenerationDate);
        await m.addColumn(events, events.reminderEnabled);
        await m.addColumn(events, events.reminderMode);
        await m.addColumn(events, events.reminderMinutesBefore);
      }
      if (from < 12) {
        // v11 -> v12: habits glow-up — optional category (Categories,
        // kind='habit') and an optional note per log. Both nullable, no
        // backfill needed.
        await m.addColumn(habits, habits.categoryId);
        await m.addColumn(habitLogs, habitLogs.notes);
      }
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'life_manager',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
