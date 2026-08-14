import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'categories_table.dart';
import 'documents_tables.dart';

/// User-manageable account kinds (checking, savings, credit card, ...) —
/// seeded with the app's original fixed set on first launch, but rows can be
/// added/edited/deleted afterward. [Accounts.type] stores the matching
/// [name] (not this row's id) so pre-existing accounts keep working without
/// a data migration.
class AccountTypes extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get icon => text().withDefault(const Constant('account_balance_wallet'))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// checking | savings | credit_card | cash | investment | any [AccountTypes.name]
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

  /// upi | cash | card | net_banking | other — a small fixed set (see
  /// `PaymentModes` in payment_mode.dart), not user-manageable like
  /// categories/account types, so no backing table.
  TextColumn get paymentMode => text().nullable()();

  /// A scanned/photographed receipt filed in the shared [Documents] table
  /// (same storage `import` and thumbnailing `Notes`/`Documents` already
  /// use), rather than a separate image column — keeps one place that owns
  /// file bytes on disk.
  TextColumn get receiptDocumentId => text().nullable().references(Documents, #id)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// A template that auto-generates real [Transactions] rows on a schedule
/// (subscriptions, rent, EMIs, salary, ...). Each generated transaction is a
/// normal row, indistinguishable from a manually entered one — this table
/// only tracks the schedule and where it's up to ([nextDueDate]).
class RecurringTransactions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get accountId => text().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get merchant => text()();

  /// Positive = income, negative = expense — same convention as
  /// [Transactions.amountMinor].
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get paymentMode => text().nullable()();

  /// daily | weekly | monthly | yearly
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();

  /// The next occurrence still to be generated. Advances by [frequency]
  /// each time `FinanceRepository.generateDueRecurringTransactions` fires
  /// it — comparing against "now" rather than storing a fixed list of dates
  /// means a catch-up after the app was closed for a while just generates
  /// every occurrence it missed, same as if it had been open the whole time.
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Paused (not deleted) recurring transactions stop generating but keep
  /// their history and schedule, so resuming later picks up correctly.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

/// An upcoming payment obligation (electricity, credit card, insurance
/// premium) tracked separately from [RecurringTransactions] because a bill
/// needs a human to confirm the amount and actually pay it — it's a
/// reminder-to-pay, not an auto-entered transaction. Marking one paid
/// writes a real [Transactions] row for that payment and, for a repeating
/// bill, advances [dueDate] to the next cycle.
class Bills extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Positive magnitude — the expense transaction written on payment is
  /// this negated, matching [Transactions.amountMinor]'s signed convention.
  IntColumn get amountMinor => integer()();
  DateTimeColumn get dueDate => dateTime()();

  /// once | monthly | yearly. A `once` bill is archived ([active] false)
  /// once paid instead of rescheduling.
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();

  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(true))();

  /// notification | alarm — see `ReminderMode`.
  TextColumn get reminderMode =>
      text().withDefault(const Constant('notification'))();

  /// How many days before [dueDate] the reminder fires — 0 means "on the
  /// due date itself".
  IntColumn get reminderDaysBefore => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastPaidDate => dateTime().nullable()();

  /// False once a one-time bill is paid — dropped from the upcoming list
  /// but its payment history (the Transaction it wrote) stays intact.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

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
