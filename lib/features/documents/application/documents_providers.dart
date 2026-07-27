import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/services/file_storage_service.dart';
import '../data/documents_repository.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  return DocumentsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStorageServiceProvider),
  );
});

final documentFoldersProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(documentsRepositoryProvider).watchFolders();
});

final documentsListProvider = StreamProvider<List<Document>>((ref) {
  return ref.watch(documentsRepositoryProvider).watchDocuments();
});

/// Folder name -> document count, for the folder grid's subtitle.
final documentCountByFolderProvider = Provider<Map<String, int>>((ref) {
  final documents = ref.watch(documentsListProvider).value ?? const [];
  final counts = <String, int>{};
  for (final d in documents) {
    final folderId = d.folderId;
    if (folderId == null) continue;
    counts[folderId] = (counts[folderId] ?? 0) + 1;
  }
  return counts;
});

class DocumentsController {
  DocumentsController(this._repo);

  final DocumentsRepository _repo;

  Future<void> createFolder(String name) => _repo.createFolder(name);

  Future<void> importDocument({
    required File source,
    required String originalName,
    String? title,
    String? folderId,
  }) {
    return _repo.importAndCreateDocument(
      source: source,
      originalName: originalName,
      title: title,
      folderId: folderId,
    );
  }

  Future<void> deleteDocument(Document document) => _repo.deleteDocument(document);
}

final documentsControllerProvider = Provider<DocumentsController>((ref) {
  return DocumentsController(ref.watch(documentsRepositoryProvider));
});
