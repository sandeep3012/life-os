import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/documents/data/documents_repository.dart';
import 'package:life_manager/features/notes/data/notes_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('notes_docs_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('notes: folder + note CRUD', () async {
    final repo = NotesRepository(db);
    await repo.createFolder('Work');
    final folder = (await db.select(db.folders).get()).single;

    final noteId = await repo.createNote(
      title: 'Q3 planning notes',
      body: 'Discussed budget reallocation',
      folderId: folder.id,
    );

    var notes = await repo.watchNotes().first;
    expect(notes, hasLength(1));
    expect(notes.first.folderId, folder.id);

    await repo.updateNote(id: noteId, title: 'Q3 planning notes (final)', body: 'Updated', folderId: null);
    notes = await repo.watchNotes().first;
    expect(notes.first.title, 'Q3 planning notes (final)');
    expect(notes.first.folderId, isNull);

    await repo.deleteNote(noteId);
    notes = await repo.watchNotes().first;
    expect(notes, isEmpty);
  });

  test('documents: import creates a row and deleting removes the file', () async {
    final storage = FileStorageService();
    final repo = DocumentsRepository(db, storage);
    await repo.createFolder('Receipts');
    final folder = (await db.select(db.folders).get()).single;

    final source = File('${tempDir.path}/rent.txt')..writeAsStringSync('receipt contents');
    await repo.importAndCreateDocument(
      source: source,
      originalName: 'rent_receipt.txt',
      title: 'Rent receipt',
      folderId: folder.id,
    );

    final documents = await repo.watchDocuments().first;
    expect(documents, hasLength(1));
    final document = documents.single;
    expect(document.title, 'Rent receipt');
    expect(document.folderId, folder.id);

    final storedFile = await storage.absoluteFile(document.filePath);
    expect(await storedFile.exists(), isTrue);

    await repo.deleteDocument(document);
    expect(await repo.watchDocuments().first, isEmpty);
    expect(await storedFile.exists(), isFalse);
  });
}
