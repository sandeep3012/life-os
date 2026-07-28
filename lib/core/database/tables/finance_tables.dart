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

class Budgets extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get categoryId => text().references(Categories, #id)();

  /// weekly | monthly
  TextColumn get period => text().withDefault(const Constant('monthly'))();
  IntColumn get limitMinor => integer()();
  DateTimeColumn get startDate => dateTime()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
