import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Folder>> watchFolders() {
    return (_db.select(
      _db.folders,
    )..where((f) => f.scope.equals('notes'))).watch();
  }

  Stream<List<Note>> watchNotes() {
    return (_db.select(
      _db.notes,
    )..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])).watch();
  }

  Future<void> createFolder(String name) {
    return _db.into(_db.folders).insert(
      FoldersCompanion.insert(name: name, scope: 'notes'),
    );
  }

  Future<String> createNote({
    required String title,
    String body = '',
    String? folderId,
  }) async {
    final row = await _db.into(_db.notes).insertReturning(
      NotesCompanion.insert(
        title: title,
        body: Value(body),
        folderId: Value(folderId),
      ),
    );
    return row.id;
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String body,
    String? folderId,
  }) {
    return (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        title: Value(title),
        body: Value(body),
        folderId: Value(folderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteNote(String id) {
    return (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
  }
}
