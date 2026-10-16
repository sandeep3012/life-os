import 'package:drift/drift.dart';

import 'app_database.dart';

/// Rows as they were just before a delete, so Undo can put them back
/// exactly — same ids, so anything pointing at them (tags, goal links,
/// reminders) reconnects by itself. Rows that were changed rather than
/// deleted (a repeating series' end date) are kept as they were too, and
/// restored the same way.
class DeletedRows {
  DeletedRows([List<(TableInfo<Table, dynamic>, Insertable<dynamic>)>? rows])
    : _rows = rows ?? [];

  final List<(TableInfo<Table, dynamic>, Insertable<dynamic>)> _rows;

  void add(TableInfo<Table, dynamic> table, Insertable<dynamic> row) =>
      _rows.add((table, row));

  void addAll(
    TableInfo<Table, dynamic> table,
    Iterable<Insertable<dynamic>> rows,
  ) {
    for (final row in rows) {
      add(table, row);
    }
  }

  /// How many rows of [table] are held — e.g. "3 tasks deleted".
  int countOf(TableInfo<Table, dynamic> table) =>
      _rows.where((r) => r.$1.actualTableName == table.actualTableName).length;

  bool get isEmpty => _rows.isEmpty;

  /// Writes every held row back, replacing whatever has its key now.
  Future<void> restore(AppDatabase db) => db.transaction(() async {
    for (final (table, row) in _rows) {
      await db.into(table).insertOnConflictUpdate(row);
    }
  });
}
