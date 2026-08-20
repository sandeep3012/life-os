import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import 'file_storage_service.dart';

const _backupFormatVersion = 1;
const _manifestEntryName = 'backup.json';
const _filesPrefix = 'files/';

/// Thrown when [BackupService.importBackup] is given something that isn't a
/// LifeOS backup archive — surfaced to the user as-is via [message].
class InvalidBackupException implements Exception {
  const InvalidBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Full backup/restore across every module: a single zip containing one JSON
/// manifest (every table, as rows) plus copies of every file a `Document`
/// references. Restoring **replaces** all local data — this is a
/// device-migration/disaster-recovery tool, not a merge — so the caller must
/// get explicit confirmation before calling [importBackup].
class BackupService {
  BackupService(this._db, this._storage);

  final AppDatabase _db;
  final FileStorageService _storage;

  Future<Uint8List> exportBackup() async {
    final tables = <String, List<Map<String, dynamic>>>{
      'categories': (await _db.select(_db.categories).get()).map((e) => e.toJson()).toList(),
      'tags': (await _db.select(_db.tags).get()).map((e) => e.toJson()).toList(),
      'entityTags': (await _db.select(_db.entityTags).get()).map((e) => e.toJson()).toList(),
      'accounts': (await _db.select(_db.accounts).get()).map((e) => e.toJson()).toList(),
      'transactions': (await _db.select(_db.transactions).get()).map((e) => e.toJson()).toList(),
      'budgets': (await _db.select(_db.budgets).get()).map((e) => e.toJson()).toList(),
      'habits': (await _db.select(_db.habits).get()).map((e) => e.toJson()).toList(),
      'habitLogs': (await _db.select(_db.habitLogs).get()).map((e) => e.toJson()).toList(),
      'tasks': (await _db.select(_db.tasks).get()).map((e) => e.toJson()).toList(),
      'subtasks': (await _db.select(_db.subtasks).get()).map((e) => e.toJson()).toList(),
      'goals': (await _db.select(_db.goals).get()).map((e) => e.toJson()).toList(),
      'goalLinks': (await _db.select(_db.goalLinks).get()).map((e) => e.toJson()).toList(),
      'goalMilestones': (await _db.select(_db.goalMilestones).get()).map((e) => e.toJson()).toList(),
      'events': (await _db.select(_db.events).get()).map((e) => e.toJson()).toList(),
      'folders': (await _db.select(_db.folders).get()).map((e) => e.toJson()).toList(),
      'notes': (await _db.select(_db.notes).get()).map((e) => e.toJson()).toList(),
      'documents': (await _db.select(_db.documents).get()).map((e) => e.toJson()).toList(),
      'insights': (await _db.select(_db.insights).get()).map((e) => e.toJson()).toList(),
      'appSettings': (await _db.select(_db.appSettings).get()).map((e) => e.toJson()).toList(),
    };

    final manifest = {
      'app': 'lifeos',
      'formatVersion': _backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };

    final archive = Archive();
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile(_manifestEntryName, manifestBytes.length, manifestBytes));

    // Bundle every file a Document references — otherwise a restore leaves
    // behind rows pointing at files that don't exist on the new device.
    final documents = await _db.select(_db.documents).get();
    final seenPaths = <String>{};
    for (final doc in documents) {
      for (final relPath in [
        doc.filePath,
        if (doc.thumbnailPath != null) doc.thumbnailPath!,
      ]) {
        if (!seenPaths.add(relPath)) continue;
        final file = await _storage.absoluteFile(relPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile('$_filesPrefix$relPath', bytes.length, bytes));
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes);
  }

  Future<void> importBackup(Uint8List zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const InvalidBackupException('That file isn\'t a valid LifeOS backup.');
    }

    final manifestFile = archive.files
        .where((f) => f.name == _manifestEntryName)
        .firstOrNull;
    if (manifestFile == null) {
      throw const InvalidBackupException('That file isn\'t a valid LifeOS backup.');
    }

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
    } catch (_) {
      throw const InvalidBackupException('That backup file is corrupted.');
    }

    final tables = manifest['tables'];
    if (manifest['app'] != 'lifeos' || tables is! Map) {
      throw const InvalidBackupException('That file isn\'t a valid LifeOS backup.');
    }

    await _db.transaction(() async {
      // Children first, so nothing is ever left referencing a deleted parent
      // mid-wipe (this DB doesn't enforce FKs, but there's no reason to rely
      // on that).
      await _db.delete(_db.entityTags).go();
      await _db.delete(_db.subtasks).go();
      await _db.delete(_db.goalLinks).go();
      await _db.delete(_db.goalMilestones).go();
      await _db.delete(_db.habitLogs).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.events).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.notes).go();
      await _db.delete(_db.documents).go();
      await _db.delete(_db.folders).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.insights).go();
      await _db.delete(_db.appSettings).go();

      // Parents first on the way back in.
      await _insertAll(_db.categories, tables['categories'], Category.fromJson);
      await _insertAll(_db.tags, tables['tags'], Tag.fromJson);
      await _insertAll(_db.accounts, tables['accounts'], Account.fromJson);
      await _insertAll(_db.folders, tables['folders'], Folder.fromJson);
      await _insertAll(_db.habits, tables['habits'], Habit.fromJson);
      await _insertAll(_db.goals, tables['goals'], Goal.fromJson);
      await _insertAll(_db.tasks, tables['tasks'], Task.fromJson);
      await _insertAll(_db.appSettings, tables['appSettings'], AppSetting.fromJson);
      await _insertAll(_db.insights, tables['insights'], Insight.fromJson);

      await _insertAll(_db.entityTags, tables['entityTags'], EntityTag.fromJson);
      await _insertAll(_db.transactions, tables['transactions'], Transaction.fromJson);
      await _insertAll(_db.budgets, tables['budgets'], Budget.fromJson);
      await _insertAll(_db.habitLogs, tables['habitLogs'], HabitLog.fromJson);
      await _insertAll(_db.subtasks, tables['subtasks'], Subtask.fromJson);
      await _insertAll(_db.goalLinks, tables['goalLinks'], GoalLink.fromJson);
      await _insertAll(_db.goalMilestones, tables['goalMilestones'], GoalMilestone.fromJson);
      await _insertAll(_db.events, tables['events'], Event.fromJson);
      await _insertAll(_db.notes, tables['notes'], Note.fromJson);
      await _insertAll(_db.documents, tables['documents'], Document.fromJson);
    });

    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(_filesPrefix)) continue;
      final relPath = file.name.substring(_filesPrefix.length);
      final dest = await _storage.absoluteFile(relPath);
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(file.content as List<int>);
    }
  }

  Future<void> _insertAll<T extends Table, D>(
    TableInfo<T, D> table,
    dynamic jsonList,
    D Function(Map<String, dynamic>) fromJson,
  ) async {
    if (jsonList is! List) return;
    for (final item in jsonList) {
      final row = fromJson(item as Map<String, dynamic>);
      await _db.into(table).insertOnConflictUpdate(row as Insertable<D>);
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(appDatabaseProvider), ref.watch(fileStorageServiceProvider));
});
