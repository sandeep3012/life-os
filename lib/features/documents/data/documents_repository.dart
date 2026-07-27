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

  Future<void> createFolder(String name) {
    return _db.into(_db.folders).insert(
      FoldersCompanion.insert(name: name, scope: 'documents'),
    );
  }

  Future<void> importAndCreateDocument({
    required File source,
    required String originalName,
    String? title,
    String? folderId,
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
      ),
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
