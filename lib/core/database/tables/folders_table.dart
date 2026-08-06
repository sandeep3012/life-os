import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// One folder table shared by Notes and Documents (distinguished by [scope])
/// rather than two near-identical tables — both screens use the same
/// "folder with optional parent" shape (Work/Personal/Ideas for notes,
/// Identity/Receipts/Insurance/Warranties for documents).
class Folders extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();

  /// notes | documents
  TextColumn get scope => text()();
  TextColumn get parentFolderId => text().nullable().references(Folders, #id)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
