import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import 'file_storage_service.dart';

const _backupFormatVersion = 3;
const _legacyMissingTables = {'accountTypes', 'recurringTransactions', 'bills'};
const _healthLearnTables = {
  'medications',
  'medicationLogs',
  'workoutDays',
  'exercises',
  'workoutLogs',
  'exerciseSetLogs',
  'learnBooks',
  'learnNotes',
};
const _tableNames = {
  ..._healthLearnTables,
  'categories',
  'tags',
  'entityTags',
  'accountTypes',
  'accounts',
  'transactions',
  'recurringTransactions',
  'bills',
  'budgets',
  'habits',
  'habitLogs',
  'tasks',
  'subtasks',
  'goals',
  'goalLinks',
  'goalMilestones',
  'events',
  'folders',
  'notes',
  'documents',
  'insights',
  'appSettings',
};
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

/// The backup is password-protected and none (or no usable one) was given.
class BackupPasswordRequired implements Exception {
  const BackupPasswordRequired({this.wrong = false});

  /// A password was given, and it doesn't open this backup.
  final bool wrong;

  @override
  String toString() =>
      wrong ? "That password doesn't open this backup." : 'Password needed.';
}

/// A backup written to disk by [BackupService.exportBackupFile].
class BackupExport {
  const BackupExport({
    required this.file,
    required this.documentFiles,
    required this.missingFiles,
    required this.sizeBytes,
  });

  /// The zip, in a temporary folder of its own — call [discard] when it has
  /// been saved or shared.
  final File file;

  /// Document files the backup carries.
  final int documentFiles;

  /// Documents whose file isn't on this phone — one that arrived through
  /// sync, which carries the record but not the file. Their records are in
  /// the backup; the files can't be.
  final int missingFiles;

  final int sizeBytes;

  Future<void> discard() async {
    try {
      await file.parent.delete(recursive: true);
    } on FileSystemException {
      // The system clears its temporary folder anyway.
    }
  }
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

  /// The backup as bytes. Holds the whole file in memory: fine for tests and
  /// small backups; the app exports with [exportBackupFile].
  Future<Uint8List> exportBackup({String? password}) async {
    final export = await exportBackupFile(password: password);
    try {
      return await export.file.readAsBytes();
    } finally {
      await export.discard();
    }
  }

  /// Writes the backup to a temporary file, a document at a time, so a large
  /// document library is never held in memory. With a [password] every entry
  /// is AES-256 encrypted (a standard password-protected zip).
  Future<BackupExport> exportBackupFile({String? password}) async {
    final snapshot = await _db.transaction(_readSnapshot);
    final dir = await Directory.systemTemp.createTemp('lifeos-backup');
    final zip = File(p.join(dir.path, 'backup.zip'));
    final encoder = ZipFileEncoder(
      password: password == null || password.isEmpty ? null : password,
    )..create(zip.path);
    var written = 0;
    var missing = 0;
    try {
      encoder.addArchiveFile(
        ArchiveFile(
          _manifestEntryName,
          snapshot.manifest.length,
          snapshot.manifest,
        ),
      );
      // Bundle every file a Document references — otherwise a restore leaves
      // behind rows pointing at files that don't exist on the new device.
      final seenPaths = <String>{};
      for (final doc in snapshot.documents) {
        for (final relPath in [
          doc.filePath,
          if (doc.thumbnailPath != null) doc.thumbnailPath!,
        ]) {
          if (!seenPaths.add(relPath)) continue;
          final file = await _storage.absoluteFile(relPath);
          if (await file.exists()) {
            await encoder.addFile(file, '$_filesPrefix$relPath');
            if (relPath == doc.filePath) written++;
          } else if (relPath == doc.filePath) {
            missing++;
          }
        }
      }
      await encoder.close();
    } on Object {
      try {
        await encoder.close();
      } on Object {
        // Already failing; the temporary folder goes either way.
      }
      await dir.delete(recursive: true);
      rethrow;
    }
    return BackupExport(
      file: zip,
      documentFiles: written,
      missingFiles: missing,
      sizeBytes: await zip.length(),
    );
  }

  /// Every table as JSON rows, read in one transaction so the backup is a
  /// single moment in time.
  Future<({Uint8List manifest, List<Document> documents})>
  _readSnapshot() async {
    final tables = <String, List<Map<String, dynamic>>>{
      'medications': (await _db.select(_db.medications).get())
          .map((e) => e.toJson())
          .toList(),
      'medicationLogs': (await _db.select(_db.medicationLogs).get())
          .map((e) => e.toJson())
          .toList(),
      'workoutDays': (await _db.select(_db.workoutDays).get())
          .map((e) => e.toJson())
          .toList(),
      'exercises': (await _db.select(_db.exercises).get())
          .map((e) => e.toJson())
          .toList(),
      'workoutLogs': (await _db.select(_db.workoutLogs).get())
          .map((e) => e.toJson())
          .toList(),
      'exerciseSetLogs': (await _db.select(_db.exerciseSetLogs).get())
          .map((e) => e.toJson())
          .toList(),
      'learnBooks': (await _db.select(_db.learnBooks).get())
          .map((e) => e.toJson())
          .toList(),
      'learnNotes': (await _db.select(_db.learnNotes).get())
          .map((e) => e.toJson())
          .toList(),
      'categories': (await _db.select(_db.categories).get())
          .map((e) => e.toJson())
          .toList(),
      'tags': (await _db.select(_db.tags).get())
          .map((e) => e.toJson())
          .toList(),
      'entityTags': (await _db.select(_db.entityTags).get())
          .map((e) => e.toJson())
          .toList(),
      'accounts': (await _db.select(_db.accounts).get())
          .map((e) => e.toJson())
          .toList(),
      'accountTypes': (await _db.select(_db.accountTypes).get())
          .map((e) => e.toJson())
          .toList(),
      'recurringTransactions':
          (await _db.select(_db.recurringTransactions).get())
              .map((e) => e.toJson())
              .toList(),
      'bills': (await _db.select(_db.bills).get())
          .map((e) => e.toJson())
          .toList(),
      'transactions': (await _db.select(_db.transactions).get())
          .map((e) => e.toJson())
          .toList(),
      'budgets': (await _db.select(_db.budgets).get())
          .map((e) => e.toJson())
          .toList(),
      'habits': (await _db.select(_db.habits).get())
          .map((e) => e.toJson())
          .toList(),
      'habitLogs': (await _db.select(_db.habitLogs).get())
          .map((e) => e.toJson())
          .toList(),
      'tasks': (await _db.select(_db.tasks).get())
          .map((e) => e.toJson())
          .toList(),
      'subtasks': (await _db.select(_db.subtasks).get())
          .map((e) => e.toJson())
          .toList(),
      'goals': (await _db.select(_db.goals).get())
          .map((e) => e.toJson())
          .toList(),
      'goalLinks': (await _db.select(_db.goalLinks).get())
          .map((e) => e.toJson())
          .toList(),
      'goalMilestones': (await _db.select(_db.goalMilestones).get())
          .map((e) => e.toJson())
          .toList(),
      'events': (await _db.select(_db.events).get())
          .map((e) => e.toJson())
          .toList(),
      'folders': (await _db.select(_db.folders).get())
          .map((e) => e.toJson())
          .toList(),
      'notes': (await _db.select(_db.notes).get())
          .map((e) => e.toJson())
          .toList(),
      'documents': (await _db.select(_db.documents).get())
          .map((e) => e.toJson())
          .toList(),
      'insights': (await _db.select(_db.insights).get())
          .map((e) => e.toJson())
          .toList(),
      'appSettings': (await _db.select(_db.appSettings).get())
          .map((e) => e.toJson())
          .toList(),
    };

    final manifest = {
      'app': 'lifeos',
      'formatVersion': _backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'tables': tables,
    };
    return (
      manifest: Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
      documents: await _db.select(_db.documents).get(),
    );
  }

  /// Restores from a backup held in memory. See [importBackupFile].
  Future<void> importBackup(Uint8List zipBytes, {String? password}) => _restore(
    InputMemoryStream(zipBytes),
    password,
    encrypted: _isEncryptedZip(zipBytes),
  );

  /// Restores from a backup file, reading it from disk as it goes. Throws
  /// [BackupPasswordRequired] for a protected backup with no (or the wrong)
  /// [password], before anything is changed.
  Future<void> importBackupFile(File file, {String? password}) async {
    final encrypted = await isPasswordProtected(file);
    final input = InputFileStream(file.path);
    try {
      await _restore(input, password, encrypted: encrypted);
    } finally {
      await input.close();
    }
  }

  /// Whether [file] is a backup that needs a password to open.
  Future<bool> isPasswordProtected(File file) async {
    try {
      final handle = await file.open();
      try {
        return _isEncryptedZip(await handle.read(8));
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return false;
    }
  }

  /// A zip's first entry starts "PK\x03\x04", a version, then its flags;
  /// bit 0 of those says the entry is encrypted. The manifest is always the
  /// first entry of a backup.
  static bool _isEncryptedZip(List<int> head) =>
      head.length >= 8 &&
      head[0] == 0x50 &&
      head[1] == 0x4B &&
      head[2] == 0x03 &&
      head[3] == 0x04 &&
      head[6] & 0x01 != 0;

  Future<void> _restore(
    InputStream input,
    String? password, {
    required bool encrypted,
  }) async {
    final usePassword = password == null || password.isEmpty ? null : password;
    if (encrypted && usePassword == null) throw const BackupPasswordRequired();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input, password: usePassword);
    } catch (_) {
      throw const InvalidBackupException(
        'That file isn\'t a valid LifeOS backup.',
      );
    }

    final manifestFile = archive.files
        .where((f) => f.name == _manifestEntryName)
        .firstOrNull;
    if (manifestFile == null) {
      throw const InvalidBackupException(
        'That file isn\'t a valid LifeOS backup.',
      );
    }

    final Map<String, dynamic> manifest;
    try {
      manifest =
          jsonDecode(utf8.decode(manifestFile.content as List<int>))
              as Map<String, dynamic>;
    } on Object {
      // An encrypted entry that won't open, or opens to noise: the password
      // is wrong. Otherwise the file itself is damaged.
      if (encrypted) throw const BackupPasswordRequired(wrong: true);
      throw const InvalidBackupException('That backup file is corrupted.');
    }

    final tables = manifest['tables'];
    if (manifest['app'] != 'lifeos' || tables is! Map) {
      throw const InvalidBackupException(
        'That file isn\'t a valid LifeOS backup.',
      );
    }
    final version = manifest['formatVersion'];
    if (version is! int || version < 1 || version > _backupFormatVersion) {
      throw const InvalidBackupException(
        'Unsupported backup version. Please use a compatible version of LifeOS.',
      );
    }
    for (final name in _tableNames) {
      if (version < 3 &&
          _healthLearnTables.contains(name) &&
          !tables.containsKey(name)) {
        tables[name] = <dynamic>[];
      }
      if (version == 1 &&
          _legacyMissingTables.contains(name) &&
          !tables.containsKey(name)) {
        tables[name] = <dynamic>[];
      }
      final rows = tables[name];
      if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
        throw InvalidBackupException(
          'The backup has missing or invalid $name data. Nothing was restored.',
        );
      }
    }
    // Check every destination before replacing database rows or writing files.
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(_filesPrefix)) continue;
      _validateFilePath(file.name.substring(_filesPrefix.length));
    }
    for (final row in tables['documents'] as List) {
      _validateFilePath(row['filePath']);
      if (row['thumbnailPath'] != null) _validateFilePath(row['thumbnailPath']);
    }

    await _db.transaction(() async {
      // Children first, so nothing is ever left referencing a deleted parent
      // mid-wipe (this DB doesn't enforce FKs, but there's no reason to rely
      // on that).
      await _db.delete(_db.medicationLogs).go();
      await _db.delete(_db.exerciseSetLogs).go();
      await _db.delete(_db.workoutLogs).go();
      await _db.delete(_db.exercises).go();
      await _db.delete(_db.workoutDays).go();
      await _db.delete(_db.medications).go();
      await _db.delete(_db.learnNotes).go();
      await _db.delete(_db.learnBooks).go();
      await _db.delete(_db.entityTags).go();
      await _db.delete(_db.subtasks).go();
      await _db.delete(_db.goalLinks).go();
      await _db.delete(_db.goalMilestones).go();
      await _db.delete(_db.habitLogs).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.recurringTransactions).go();
      await _db.delete(_db.bills).go();
      await _db.delete(_db.events).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.goals).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.accounts).go();
      await _db.delete(_db.accountTypes).go();
      await _db.delete(_db.notes).go();
      await _db.delete(_db.documents).go();
      await _db.delete(_db.folders).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.insights).go();
      await _db.delete(_db.appSettings).go();

      // Parents first on the way back in.
      await _insertAll(
        _db.medications,
        tables['medications'],
        Medication.fromJson,
      );
      await _insertAll(
        _db.medicationLogs,
        tables['medicationLogs'],
        MedicationLog.fromJson,
      );
      await _insertAll(
        _db.workoutDays,
        tables['workoutDays'],
        WorkoutDay.fromJson,
      );
      await _insertAll(_db.exercises, tables['exercises'], Exercise.fromJson);
      await _insertAll(
        _db.workoutLogs,
        tables['workoutLogs'],
        WorkoutLog.fromJson,
      );
      await _insertAll(
        _db.exerciseSetLogs,
        tables['exerciseSetLogs'],
        ExerciseSetLog.fromJson,
      );
      await _insertAll(
        _db.learnBooks,
        tables['learnBooks'],
        LearnBook.fromJson,
      );
      await _insertAll(
        _db.learnNotes,
        tables['learnNotes'],
        LearnNote.fromJson,
      );
      await _insertAll(
        _db.categories,
        tables['categories'],
        (json) => Category.fromJson({'position': 0, ...json}),
      );
      await _insertAll(_db.tags, tables['tags'], Tag.fromJson);
      await _insertAll(
        _db.accountTypes,
        tables['accountTypes'],
        AccountType.fromJson,
      );
      // Backups from before v33 have no order or default: they come back
      // in creation order (position ties sort by it) with no default.
      await _insertAll(
        _db.accounts,
        tables['accounts'],
        (json) => Account.fromJson({
          'position': 0,
          'isDefault': false,
          'openingBalanceMinor': 0,
          ...json,
        }),
      );
      await _insertAll(_db.folders, tables['folders'], Folder.fromJson);
      await _insertAll(_db.habits, tables['habits'], Habit.fromJson);
      await _insertAll(_db.goals, tables['goals'], Goal.fromJson);
      await _insertAll(_db.tasks, tables['tasks'], Task.fromJson);
      await _insertAll(
        _db.appSettings,
        tables['appSettings'],
        (json) => AppSetting.fromJson({
          ..._settingsAddedSinceV28,
          ...json,
          // Never carried across: sending speech to the AI service is
          // agreed to on each phone, so a restored backup asks again.
          'voiceEntryConsent': false,
        }),
      );
      await _insertAll(_db.insights, tables['insights'], Insight.fromJson);

      await _insertAll(
        _db.entityTags,
        tables['entityTags'],
        EntityTag.fromJson,
      );
      await _insertAll(
        _db.transactions,
        tables['transactions'],
        Transaction.fromJson,
      );
      await _insertAll(
        _db.recurringTransactions,
        tables['recurringTransactions'],
        RecurringTransaction.fromJson,
      );
      await _insertAll(_db.bills, tables['bills'], Bill.fromJson);
      await _insertAll(_db.budgets, tables['budgets'], Budget.fromJson);
      await _insertAll(_db.habitLogs, tables['habitLogs'], HabitLog.fromJson);
      await _insertAll(_db.subtasks, tables['subtasks'], Subtask.fromJson);
      await _insertAll(_db.goalLinks, tables['goalLinks'], GoalLink.fromJson);
      await _insertAll(
        _db.goalMilestones,
        tables['goalMilestones'],
        GoalMilestone.fromJson,
      );
      await _insertAll(_db.events, tables['events'], Event.fromJson);
      await _insertAll(_db.notes, tables['notes'], Note.fromJson);
      await _insertAll(_db.documents, tables['documents'], Document.fromJson);

      // Accounts from before opening balances existed: work them out from
      // the balances and transactions the backup carries, so neither
      // changes. Accounts that have one keep it exactly.
      final withoutOpening = [
        for (final row in (tables['accounts'] as List?) ?? const [])
          if (row is Map && !row.containsKey('openingBalanceMinor')) row['id'],
      ];
      for (final id in withoutOpening) {
        await _db.customStatement(
          'UPDATE accounts SET opening_balance_minor = balance_minor - '
          '(SELECT COALESCE(SUM(amount_minor), 0) FROM transactions '
          'WHERE transactions.account_id = accounts.id) WHERE id = ?',
          [id],
        );
      }
    });

    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith(_filesPrefix)) continue;
      final relPath = file.name.substring(_filesPrefix.length);
      final dest = await _storage.absoluteFile(relPath);
      await dest.parent.create(recursive: true);
      // Straight to disk, a block at a time, rather than through memory.
      final out = OutputFileStream(dest.path);
      try {
        file.writeContent(out);
      } finally {
        await out.close();
      }
    }
  }

  /// Settings columns newer than some backups. `fromJson` throws on a missing
  /// non-null column, so without these a backup made before they existed
  /// would fail to restore at all. Each value is the column's own default.
  static const _settingsAddedSinceV28 = <String, dynamic>{
    'reduceMotion': false,
    'transitionEffectsEnabled': true,
    // A backup from before onboarding existed belongs to someone who has
    // been using the app; don't walk them through it again.
    'onboardingCompleted': true,
    'toursSeen': 'home',
    'alarmTone': 'gentle',
    'soundEffectsEnabled': true,
    'voiceEntryConsent': false,
    'fontStyle': 'classic',
    'backgroundStyle': 'recommended',
  };

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

  void _validateFilePath(dynamic path) {
    if (path is! String ||
        path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains(':') ||
        path.contains('\u0000') ||
        path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const InvalidBackupException(
        'The backup contains an unsafe document path.',
      );
    }
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(fileStorageServiceProvider),
  );
});
