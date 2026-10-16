import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/calendar/data/calendar_repository.dart';
import 'package:life_manager/features/documents/data/documents_repository.dart';
import 'package:life_manager/features/notes/data/notes_repository.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<Task>> tasks() => (db.select(db.tasks)
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .get();

  test('a deleted task comes back with its subtasks and tick', () async {
    final repo = TasksRepository(db);
    final id = await repo.createTask(title: 'Pack', dueDate: DateTime(2026, 11, 1));
    await repo.setTaskDone(id, true);
    await db.into(db.subtasks).insert(
      SubtasksCompanion.insert(taskId: id, title: 'Charger'),
    );
    final before = (await tasks()).single;

    final removed = await repo.deleteTask(id);
    expect(await tasks(), isEmpty);
    expect(await db.select(db.subtasks).get(), isEmpty);

    await repo.restore(removed);
    final after = (await tasks()).single;
    expect(after, before);
    expect((await db.select(db.subtasks).getSingle()).title, 'Charger');
  });

  test('undoing "this and future" puts the series back as it was', () async {
    final repo = TasksRepository(db);
    final now = DateTime.now();
    await repo.createTask(
      title: 'Gym',
      schedule: RepeatSchedule(
        start: DateTime(now.year, now.month, now.day - 7, 7),
        frequency: 'weekly',
      ),
    );
    final before = await tasks();

    final removed = await repo.deleteFollowingTasks(before[2]);
    expect((await tasks()).length, 2);

    await repo.restore(removed);
    expect(await tasks(), before, reason: 'rows and the head schedule restored');
  });

  test('an event series and a note come back after delete', () async {
    final calendar = CalendarRepository(db);
    final start = DateTime(2026, 11, 2, 9);
    final event = await calendar.createEvent(
      title: 'Standup',
      startTime: start,
      frequency: 'daily',
    );
    final series = await calendar.getEventsInSeries(event.recurrenceId!);
    final removed = await calendar.deleteEventSeries(event.recurrenceId!);
    expect(await db.select(db.events).get(), isEmpty);
    await calendar.restore(removed);
    expect(await calendar.getEventsInSeries(event.recurrenceId!), hasLength(series.length));

    final notes = NotesRepository(db);
    final noteId = await notes.createNote(title: 'Ideas', body: 'Ship it');
    final gone = await notes.deleteNote(noteId);
    expect(await db.select(db.notes).get(), isEmpty);
    await notes.restore(gone);
    expect((await db.select(db.notes).getSingle()).body, 'Ship it');
  });

  test('a deleted document keeps its file until Undo is no longer offered', () async {
    final dir = await Directory.systemTemp.createTemp('lifeos_doc_');
    addTearDown(() => dir.delete(recursive: true));
    final storage = _TempStorage(dir);
    final repo = DocumentsRepository(db, storage);
    final file = File('${dir.path}/docs/a.pdf')..createSync(recursive: true);
    await db.into(db.documents).insert(
      DocumentsCompanion.insert(
        title: 'Lease',
        filePath: 'docs/a.pdf',
        mimeType: 'application/pdf',
      ),
    );
    final doc = await db.select(db.documents).getSingle();

    // Undone: the file is still there and stays.
    final removed = await repo.deleteDocument(doc);
    expect(await db.select(db.documents).get(), isEmpty);
    expect(file.existsSync(), isTrue);
    await repo.restore(removed);
    await repo.discardFile(doc);
    expect(file.existsSync(), isTrue);
    expect((await db.select(db.documents).getSingle()).title, 'Lease');

    // Not undone: the file goes.
    await repo.deleteDocument(doc);
    await repo.discardFile(doc);
    expect(file.existsSync(), isFalse);
  });
}

class _TempStorage extends FileStorageService {
  _TempStorage(this.dir);
  final Directory dir;

  @override
  Future<File> absoluteFile(String relativePath) async =>
      File('${dir.path}/$relativePath');

  @override
  Future<void> deleteFile(String relativePath, {String? thumbnailRelativePath}) async {
    final f = File('${dir.path}/$relativePath');
    if (f.existsSync()) f.deleteSync();
  }
}
