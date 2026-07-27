import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../data/notes_repository.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(ref.watch(appDatabaseProvider));
});

final noteFoldersProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(notesRepositoryProvider).watchFolders();
});

final notesListProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(notesRepositoryProvider).watchNotes();
});

class NotesController {
  NotesController(this._repo);

  final NotesRepository _repo;

  Future<void> createFolder(String name) => _repo.createFolder(name);

  Future<String> createNote({required String title, String body = '', String? folderId}) {
    return _repo.createNote(title: title, body: body, folderId: folderId);
  }

  Future<void> updateNote({
    required String id,
    required String title,
    required String body,
    String? folderId,
  }) {
    return _repo.updateNote(id: id, title: title, body: body, folderId: folderId);
  }

  Future<void> deleteNote(String id) => _repo.deleteNote(id);
}

final notesControllerProvider = Provider<NotesController>((ref) {
  return NotesController(ref.watch(notesRepositoryProvider));
});
