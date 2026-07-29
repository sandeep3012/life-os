import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'categories_table.dart';

/// checking | savings | credit_card | cash | investment
class Accounts extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get type => text()();

  /// Stored in minor currency units (e.g. paise) to avoid floating-point
  /// drift in balances — matches the Finance screen's ₹ totals exactly.
  IntColumn get balanceMinor => integer().withDefault(const Constant(0))();
  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  /// Deactivated (not deleted) accounts drop out of balance totals and
  /// picker lists but keep their transaction/goal-link history intact —
  /// the fallback for accounts that can't be hard-deleted because they're
  /// still referenced elsewhere.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get merchant => text()();

  /// Positive = income/credit, negative = expense/debit — one signed column
  /// instead of a separate `type` flag so sums are a plain SUM(amountMinor).
  IntColumn get amountMinor => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Each row is one *version* of a category's budget, not a mutable singleton
/// — editing a budget inserts/updates the version whose [effectiveMonth]
/// matches the target month rather than overwriting history, so a limit
/// change made this month doesn't retroactively change what past months
/// show. [monthBudgetsWithProgressProvider] resolves "the budget for
/// category X in month Y" by picking the latest version with
/// `effectiveMonth <= Y`. [active] is a tombstone: `false` means "no budget
/// for this category from this month forward" without erasing earlier
/// versions.
class Budgets extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get categoryId => text().references(Categories, #id)();

  /// weekly | monthly
  TextColumn get period => text().withDefault(const Constant('monthly'))();
  IntColumn get limitMinor => integer()();
  DateTimeColumn get startDate => dateTime()();

  /// First-of-month date this version takes effect from. Nullable only so
  /// the column can be added via `ALTER TABLE` on upgrade (SQLite requires a
  /// default or nullability for `NOT NULL` columns added to a non-empty
  /// table) — every row written by the app always sets it.
  DateTimeColumn get effectiveMonth => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
