import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/app_lock_service.dart';
import 'package:life_manager/core/services/backup_service.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async {
    return _store[key];
  }

  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async {
    return _store.containsKey(key);
  }

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async {
    return Map.of(_store);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }
}

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late FileStorageService storage;
  late BackupService backupService;
  late AppLockService lockService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('e2e_backup_lock_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();

    storage = FileStorageService();
    backupService = BackupService(db, storage);
    lockService = AppLockService(storage: const FlutterSecureStorage());
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('E2E App Security & Lock Lifecycle', () {
    test('PIN creation, validation, update, and deletion lifecycle with edge cases', () async {
      // 1. Initial state: No PIN
      expect(await lockService.hasPin(), isFalse);
      expect(await lockService.verifyPin('1234'), isFalse);
      expect(await lockService.verifyPin(''), isFalse);

      // 2. Set 4-digit PIN '5829'
      await lockService.setPin('5829');
      expect(await lockService.hasPin(), isTrue);
      expect(await lockService.verifyPin('5829'), isTrue);

      // Edge cases: Incorrect PINs, partial matches, whitespace
      expect(await lockService.verifyPin('582'), isFalse);
      expect(await lockService.verifyPin('58290'), isFalse);
      expect(await lockService.verifyPin('0000'), isFalse);
      expect(await lockService.verifyPin(' 5829 '), isFalse);

      // 3. Update PIN to '9941'
      await lockService.setPin('9941');
      expect(await lockService.verifyPin('5829'), isFalse);
      expect(await lockService.verifyPin('9941'), isTrue);

      // 4. Clear PIN
      await lockService.clearPin();
      expect(await lockService.hasPin(), isFalse);
      expect(await lockService.verifyPin('9941'), isFalse);
    });
  });

  group('E2E Full Multi-Module Backup, Data Wipe & Restore', () {
    test('exports comprehensive multi-module data and restores all relations and files seamlessly', () async {
      // 1. Seed complete multi-module graph
      // A. Categories & Accounts
      final category = await db.into(db.categories).insertReturning(
        CategoriesCompanion.insert(
          name: 'Investment Advisory',
          colorHex: '#2E9E63',
          kind: const Value('expense'),
        ),
      );
      final account = await db.into(db.accounts).insertReturning(
        AccountsCompanion.insert(
          name: 'HDFC Wealth Checking',
          type: 'checking',
          balanceMinor: const Value(7500000), // ₹75,000.00
        ),
      );

      // B. Transactions
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          categoryId: Value(category.id),
          merchant: 'Zerodha Broking Ltd',
          amountMinor: -150000,
          date: DateTime(2026, 8, 10, 11, 0),
        ),
      );

      // C. Habits & HabitLogs
      final habit = await db.into(db.habits).insertReturning(
        HabitsCompanion.insert(name: 'Morning Meditation 20m'),
      );
      await db.into(db.habitLogs).insert(
        HabitLogsCompanion.insert(
          habitId: habit.id,
          date: DateTime(2026, 8, 19),
          completed: const Value(true),
        ),
      );

      // D. Tasks & Subtasks
      final task = await db.into(db.tasks).insertReturning(
        TasksCompanion.insert(
          title: 'Review Quarterly Tax Filing',
          priority: const Value('high'),
          dueDate: Value(DateTime(2026, 8, 25)),
        ),
      );
      await db.into(db.subtasks).insert(
        SubtasksCompanion.insert(
          taskId: task.id,
          title: 'Collect Form 16',
          done: const Value(true),
        ),
      );

      // E. Goals, GoalLinks & GoalMilestones
      final goal = await db.into(db.goals).insertReturning(
        GoalsCompanion.insert(
          title: 'Accumulate ₹10L Portfolio',
          targetValue: const Value(100000000),
          currentValue: const Value(7500000),
        ),
      );
      await db.into(db.goalLinks).insert(
        GoalLinksCompanion.insert(
          goalId: goal.id,
          linkedType: 'account',
          linkedId: account.id,
        ),
      );
      await db.into(db.goalMilestones).insert(
        GoalMilestonesCompanion.insert(
          goalId: goal.id,
          title: 'First ₹1L saved',
          completed: const Value(true),
        ),
      );

      // F. Events
      await db.into(db.events).insert(
        EventsCompanion.insert(
          title: 'Annual Tax Consultation',
          startTime: DateTime(2026, 8, 28, 15, 0),
        ),
      );

      // G. Folders & Notes
      final noteFolder = await db.into(db.folders).insertReturning(
        FoldersCompanion.insert(name: 'Financial Planning', scope: 'notes'),
      );
      await db.into(db.notes).insert(
        NotesCompanion.insert(
          title: 'Retirement Strategy 2026',
          body: const Value('# Goals\n- Safe withdrawal rate: 4%\n- Diversified allocation'),
          folderId: Value(noteFolder.id),
        ),
      );

      // H. Folders & Documents with Real Storage File
      final docFolder = await db.into(db.folders).insertReturning(
        FoldersCompanion.insert(name: 'Tax Proofs', scope: 'documents'),
      );
      final rawFile = File('${tempDir.path}/form_16.pdf')
        ..writeAsStringSync('%PDF-1.5 Annual Tax Certificate Proof Data');
      final storedFile = await storage.importFile(rawFile, originalName: 'Form16_2026.pdf');
      await db.into(db.documents).insert(
        DocumentsCompanion.insert(
          title: 'Form 16 Tax Certificate',
          filePath: storedFile.relativePath,
          mimeType: storedFile.mimeType,
          folderId: Value(docFolder.id),
        ),
      );

      // 2. Export full backup to ZIP bytes
      final backupZip = await backupService.exportBackup();
      expect(backupZip, isNotEmpty);

      // 3. Wipe all database tables & storage
      await db.delete(db.transactions).go();
      await db.delete(db.accounts).go();
      await db.delete(db.categories).go();
      await db.delete(db.habitLogs).go();
      await db.delete(db.habits).go();
      await db.delete(db.subtasks).go();
      await db.delete(db.tasks).go();
      await db.delete(db.goalMilestones).go();
      await db.delete(db.goalLinks).go();
      await db.delete(db.goals).go();
      await db.delete(db.events).go();
      await db.delete(db.notes).go();
      await db.delete(db.documents).go();
      await db.delete(db.folders).go();
      await storage.deleteFile(storedFile.relativePath);

      // Verify wipe is clean
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
      expect(await db.select(db.goals).get(), isEmpty);
      expect(await db.select(db.notes).get(), isEmpty);
      expect(await (await storage.absoluteFile(storedFile.relativePath)).exists(), isFalse);

      // 4. Restore from the exported ZIP
      await backupService.importBackup(backupZip);

      // 5. Verify integrity across every single restored entity
      final restoredAccounts = await db.select(db.accounts).get();
      expect(restoredAccounts, hasLength(1));
      expect(restoredAccounts.single.name, 'HDFC Wealth Checking');
      expect(restoredAccounts.single.balanceMinor, 7500000);

      final restoredTxns = await db.select(db.transactions).get();
      expect(restoredTxns, hasLength(1));
      expect(restoredTxns.single.merchant, 'Zerodha Broking Ltd');
      expect(restoredTxns.single.amountMinor, -150000);

      final restoredHabits = await db.select(db.habits).get();
      expect(restoredHabits, hasLength(1));
      expect(restoredHabits.single.name, 'Morning Meditation 20m');

      final restoredHabitLogs = await db.select(db.habitLogs).get();
      expect(restoredHabitLogs, hasLength(1));
      expect(restoredHabitLogs.single.completed, isTrue);

      final restoredTasks = await db.select(db.tasks).get();
      expect(restoredTasks, hasLength(1));
      expect(restoredTasks.single.title, 'Review Quarterly Tax Filing');
      expect(restoredTasks.single.priority, 'high');

      final restoredSubtasks = await db.select(db.subtasks).get();
      expect(restoredSubtasks, hasLength(1));
      expect(restoredSubtasks.single.title, 'Collect Form 16');
      expect(restoredSubtasks.single.done, isTrue);

      final restoredGoals = await db.select(db.goals).get();
      expect(restoredGoals, hasLength(1));
      expect(restoredGoals.single.title, 'Accumulate ₹10L Portfolio');

      final restoredMilestones = await db.select(db.goalMilestones).get();
      expect(restoredMilestones, hasLength(1));
      expect(restoredMilestones.single.title, 'First ₹1L saved');
      expect(restoredMilestones.single.completed, isTrue);

      final restoredGoalLinks = await db.select(db.goalLinks).get();
      expect(restoredGoalLinks, hasLength(1));
      expect(restoredGoalLinks.single.linkedType, 'account');

      final restoredEvents = await db.select(db.events).get();
      expect(restoredEvents, hasLength(1));
      expect(restoredEvents.single.title, 'Annual Tax Consultation');

      final restoredNotes = await db.select(db.notes).get();
      expect(restoredNotes, hasLength(1));
      expect(restoredNotes.single.title, 'Retirement Strategy 2026');

      final restoredDocs = await db.select(db.documents).get();
      expect(restoredDocs, hasLength(1));
      expect(restoredDocs.single.title, 'Form 16 Tax Certificate');

      // Verify physical document file restored and readable
      final restoredFile = await storage.absoluteFile(storedFile.relativePath);
      expect(await restoredFile.exists(), isTrue);
      expect(await restoredFile.readAsString(), '%PDF-1.5 Annual Tax Certificate Proof Data');
    });

    test('importBackup rejects corrupt / non-zip data gracefully', () async {
      expect(
        () => backupService.importBackup(Uint8List.fromList([0, 1, 2, 3, 4])),
        throwsA(isA<InvalidBackupException>()),
      );
      expect(
        () => backupService.importBackup(Uint8List(0)),
        throwsA(isA<InvalidBackupException>()),
      );
    });
  });
}
