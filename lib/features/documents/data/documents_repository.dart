import 'dart:io';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/file_storage_service.dart';

class DocumentsRepository {
  DocumentsRepository(this._db, this._storage);

  final AppDatabase _db;
  final FileStorageService _storage;

  Stream<List<Folder>> watchFolders() {
    return (_db.select(
      _db.folders,
    )..where((f) => f.scope.equals('documents'))).watch();
  }

  Stream<List<Document>> watchDocuments() {
    return (_db.select(
      _db.documents,
    )..orderBy([(d) => OrderingTerm.desc(d.createdAt)])).watch();
  }

  Stream<List<Document>> watchPinnedDocuments() {
    return (_db.select(_db.documents)
          ..where((d) => d.isPinned.equals(true))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch();
  }

  Future<void> createFolder(String name, {String? iconName, String? colorHex}) {
    return _db.into(_db.folders).insert(
      FoldersCompanion.insert(
        name: name,
        scope: 'documents',
        iconName: Value(iconName),
        colorHex: Value(colorHex),
      ),
    );
  }

  Future<void> updateFolder(
    String id, {
    required String name,
    String? iconName,
    String? colorHex,
  }) {
    return (_db.update(_db.folders)..where((f) => f.id.equals(id))).write(
      FoldersCompanion(
        name: Value(name),
        iconName: Value(iconName),
        colorHex: Value(colorHex),
      ),
    );
  }

  Future<void> deleteFolder(String id) async {
    // Un-assign documents from this folder, then delete the folder.
    await (_db.update(_db.documents)..where((d) => d.folderId.equals(id)))
        .write(const DocumentsCompanion(folderId: Value(null)));
    await (_db.delete(_db.folders)..where((f) => f.id.equals(id))).go();
  }

  Future<void> importAndCreateDocument({
    required File source,
    required String originalName,
    String? title,
    String? folderId,
    bool isPinned = false,
    String? documentType,
  }) async {
    final stored = await _storage.importFile(source, originalName: originalName);
    await _db.into(_db.documents).insert(
      DocumentsCompanion.insert(
        title: title ?? originalName,
        filePath: stored.relativePath,
        thumbnailPath: Value(stored.thumbnailRelativePath),
        mimeType: stored.mimeType,
        sizeBytes: Value(stored.sizeBytes),
        folderId: Value(folderId),
        isPinned: Value(isPinned),
        documentType: Value(documentType),
      ),
    );
  }

  Future<void> updateDocument({
    required String id,
    required String title,
    String? folderId,
    bool isPinned = false,
    String? documentType,
  }) {
    return (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(
        title: Value(title),
        folderId: Value(folderId),
        isPinned: Value(isPinned),
        documentType: Value(documentType),
      ),
    );
  }

  Future<void> pinDocument(String id, {required bool pinned}) {
    return (_db.update(_db.documents)..where((d) => d.id.equals(id))).write(
      DocumentsCompanion(isPinned: Value(pinned)),
    );
  }

  Future<void> deleteDocument(Document document) async {
    await _storage.deleteFile(
      document.filePath,
      thumbnailRelativePath: document.thumbnailPath,
    );
    await (_db.delete(
      _db.documents,
    )..where((d) => d.id.equals(document.id))).go();
  }
}
