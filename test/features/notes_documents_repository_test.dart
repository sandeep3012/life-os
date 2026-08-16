import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/documents/data/documents_repository.dart';
import 'package:life_manager/features/notes/data/notes_repository.dart';
import 'package:life_manager/features/tags/data/tags_repository.dart';
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

  test('documents: updateDocument changes title and folder', () async {
    final storage = FileStorageService();
    final repo = DocumentsRepository(db, storage);
    final source = File('${tempDir.path}/note.txt')..writeAsStringSync('contents');
    await repo.importAndCreateDocument(source: source, originalName: 'note.txt');
    final document = (await repo.watchDocuments().first).single;

    await repo.createFolder('Receipts');
    final folder = (await db.select(db.folders).get()).single;

    await repo.updateDocument(id: document.id, title: 'Renamed', folderId: folder.id);
    final updated = (await repo.watchDocuments().first).single;
    expect(updated.title, 'Renamed');
    expect(updated.folderId, folder.id);
  });

  test('tags: a shared tag can be attached to both a note and a document', () async {
    final notesRepo = NotesRepository(db);
    final documentsRepo = DocumentsRepository(db, FileStorageService());
    final tagsRepo = TagsRepository(db);

    final noteId = await notesRepo.createNote(title: 'Recipe');
    final source = File('${tempDir.path}/photo.txt')..writeAsStringSync('x');
    await documentsRepo.importAndCreateDocument(source: source, originalName: 'photo.txt');
    final documentId = (await documentsRepo.watchDocuments().first).single.id;

    final tag = await tagsRepo.findOrCreateTag('Personal');
    await tagsRepo.addTagToEntity(tagId: tag.id, entityType: 'note', entityId: noteId);
    await tagsRepo.addTagToEntity(tagId: tag.id, entityType: 'document', entityId: documentId);

    final links = await tagsRepo.watchAllEntityTags().first;
    expect(links, hasLength(2));
    expect(links.map((l) => l.entityType), containsAll(['note', 'document']));

    // Removing the note's tag leaves the document's link untouched.
    await tagsRepo.removeTagFromEntity(tagId: tag.id, entityType: 'note', entityId: noteId);
    final remaining = await tagsRepo.watchAllEntityTags().first;
    expect(remaining, hasLength(1));
    expect(remaining.single.entityType, 'document');
  });
}
