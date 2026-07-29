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
    Accounts,
    Transactions,
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
  int get schemaVersion => 3;

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
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'life_manager');
}
