import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'folders_table.dart';

/// Only metadata + a relative on-device path live here; the file bytes
/// themselves are managed by `FileStorageService` (Phase 4) so this table
/// stays portable if the backing storage ever moves (e.g. to cloud sync).
class Documents extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get title => text()();
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get folderId => text().nullable().references(Folders, #id)();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();
}
