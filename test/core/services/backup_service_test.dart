import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/backup_service.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  Map<String, dynamic> manifest(Uint8List bytes) =>
      jsonDecode(
            utf8.decode(
              ZipDecoder()
                      .decodeBytes(bytes)
                      .files
                      .firstWhere((f) => f.name == 'backup.json')
                      .content
                  as List<int>,
            ),
          )
          as Map<String, dynamic>;
  Uint8List pack(Map<String, dynamic> value) {
    final bytes = utf8.encode(jsonEncode(value));
    final archive = Archive()
      ..addFile(ArchiveFile('backup.json', bytes.length, bytes));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  late AppDatabase db;
  late Directory tempDir;
  late FileStorageService storage;
  late BackupService backup;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('backup_service_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    storage = FileStorageService();
    backup = BackupService(db, storage);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'export then import restores rows and document files identically',
    () async {
      await db
          .into(db.appSettings)
          .insert(const AppSettingsCompanion(currencyCode: Value('EUR')));
      // Seed every table, including a real document file.
      final category = await db
          .into(db.categories)
          .insertReturning(
            CategoriesCompanion.insert(name: 'Dining', colorHex: '#E0475A'),
          );
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              name: 'Checking',
              type: 'checking',
              balanceMinor: const Value(50000),
            ),
          );
      await db
          .into(db.accountTypes)
          .insert(AccountTypesCompanion.insert(name: 'Custom wallet'));
      await db
          .into(db.bills)
          .insert(
            BillsCompanion.insert(
              name: 'Rent',
              amountMinor: 120000,
              accountId: Value(account.id),
              dueDate: DateTime(2026, 10, 1),
            ),
          );
      await db
          .into(db.recurringTransactions)
          .insert(
            RecurringTransactionsCompanion.insert(
              accountId: account.id,
              merchant: 'Subscription',
              amountMinor: -9900,
              nextDueDate: DateTime(2026, 10, 2),
              active: const Value(false),
            ),
          );
      final task = await db
          .into(db.tasks)
          .insertReturning(TasksCompanion.insert(title: 'Test task'));
      await db
          .into(db.subtasks)
          .insert(SubtasksCompanion.insert(taskId: task.id, title: 'Step one'));
      final tag = await db
          .into(db.tags)
          .insertReturning(TagsCompanion.insert(name: 'Home'));
      await db
          .into(db.entityTags)
          .insert(
            EntityTagsCompanion.insert(
              tagId: tag.id,
              entityType: 'task',
              entityId: task.id,
            ),
          );
      await db
          .into(db.notes)
          .insert(
            NotesCompanion.insert(
              title: 'Test note',
              body: const Value('Keep this text'),
            ),
          );
      await db
          .into(db.events)
          .insert(
            EventsCompanion.insert(
              title: 'Meeting',
              startTime: DateTime(2026, 10, 3),
            ),
          );
      await db
          .into(db.insights)
          .insert(
            InsightsCompanion.insert(
              type: 'test',
              severity: 'info',
              title: 'Insight',
            ),
          );
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              categoryId: category.id,
              limitMinor: 100000,
              startDate: DateTime(2026, 9),
              effectiveMonth: Value(DateTime(2026, 9)),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              accountId: account.id,
              categoryId: Value(category.id),
              merchant: 'Swiggy',
              amountMinor: -6400,
              date: DateTime(2026, 7, 26),
            ),
          );
      final habit = await db
          .into(db.habits)
          .insertReturning(HabitsCompanion.insert(name: 'Morning workout'));
      await db
          .into(db.habitLogs)
          .insert(
            HabitLogsCompanion.insert(
              habitId: habit.id,
              date: DateTime(2026, 7, 25),
            ),
          );
      final goal = await db
          .into(db.goals)
          .insertReturning(
            GoalsCompanion.insert(
              title: 'Emergency Fund',
              targetValue: const Value(200000),
            ),
          );
      await db
          .into(db.goalLinks)
          .insert(
            GoalLinksCompanion.insert(
              goalId: goal.id,
              linkedType: 'account',
              linkedId: account.id,
            ),
          );
      await db
          .into(db.goalMilestones)
          .insert(
            GoalMilestonesCompanion.insert(
              goalId: goal.id,
              title: 'Reach first ₹50k',
              completed: const Value(true),
            ),
          );

      final folder = await db
          .into(db.folders)
          .insertReturning(
            FoldersCompanion.insert(name: 'Receipts', scope: 'documents'),
          );
      final source = File('${tempDir.path}/rent.txt')
        ..writeAsStringSync('receipt contents');
      final stored = await storage.importFile(
        source,
        originalName: 'rent_receipt.txt',
      );
      await db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              title: 'Rent receipt',
              filePath: stored.relativePath,
              mimeType: stored.mimeType,
              folderId: Value(folder.id),
            ),
          );

      final zipBytes = await backup.exportBackup();
      expect(zipBytes, isNotEmpty);
      final before = manifest(zipBytes)['tables'] as Map;
      expect(before.length, db.allTables.length);
      expect(before.values.every((rows) => (rows as List).isNotEmpty), isTrue);

      // Wipe everything, then restore from the exported bytes.
      await db.delete(db.transactions).go();
      await db.delete(db.bills).go();
      await db.delete(db.recurringTransactions).go();
      await db.delete(db.accountTypes).go();
      await db.delete(db.accounts).go();
      await db.delete(db.categories).go();
      await db.delete(db.habitLogs).go();
      await db.delete(db.habits).go();
      await db.delete(db.goalLinks).go();
      await db.delete(db.goalMilestones).go();
      await db.delete(db.goals).go();
      await db.delete(db.documents).go();
      await db.delete(db.folders).go();
      await storage.deleteFile(stored.relativePath);

      expect(await db.select(db.transactions).get(), isEmpty);
      expect(
        await (await storage.absoluteFile(stored.relativePath)).exists(),
        isFalse,
      );

      await backup.importBackup(zipBytes);
      expect(manifest(await backup.exportBackup())['tables'], before);
      expect((await db.select(db.bills).get()).single.name, 'Rent');
      expect(
        (await db.select(db.recurringTransactions).get()).single.active,
        isFalse,
      );
      expect(
        (await db.select(db.accountTypes).get()).single.name,
        'Custom wallet',
      );

      final restoredTxns = await db.select(db.transactions).get();
      expect(restoredTxns, hasLength(1));
      expect(restoredTxns.single.merchant, 'Swiggy');
      expect(restoredTxns.single.amountMinor, -6400);

      final restoredAccounts = await db.select(db.accounts).get();
      expect(restoredAccounts.single.balanceMinor, 50000);

      final restoredHabitLogs = await db.select(db.habitLogs).get();
      expect(restoredHabitLogs, hasLength(1));

      final restoredGoalLinks = await db.select(db.goalLinks).get();
      expect(restoredGoalLinks.single.linkedType, 'account');

      final restoredMilestones = await db.select(db.goalMilestones).get();
      expect(restoredMilestones, hasLength(1));
      expect(restoredMilestones.single.title, 'Reach first ₹50k');
      expect(restoredMilestones.single.completed, isTrue);

      final restoredDocs = await db.select(db.documents).get();
      expect(restoredDocs.single.title, 'Rent receipt');

      final restoredFile = await storage.absoluteFile(stored.relativePath);
      expect(await restoredFile.exists(), isTrue);
      expect(await restoredFile.readAsString(), 'receipt contents');
    },
  );

  test('importBackup rejects a file that is not a LifeOS backup', () async {
    final notABackup = File('${tempDir.path}/not-a-backup.zip')
      ..writeAsBytesSync([1, 2, 3, 4]);

    expect(
      () => backup.importBackup(notABackup.readAsBytesSync()),
      throwsA(isA<InvalidBackupException>()),
    );
  });

  test(
    'unsupported versions and missing tables leave current data untouched',
    () async {
      await db.into(db.notes).insert(NotesCompanion.insert(title: 'Keep me'));
      final original = manifest(await backup.exportBackup());
      for (final version in [null, 0, 3, '2']) {
        await expectLater(
          backup.importBackup(pack({...original, 'formatVersion': version})),
          throwsA(isA<InvalidBackupException>()),
        );
      }
      final tables = Map<String, dynamic>.from(original['tables'] as Map)
        ..remove('bills');
      await expectLater(
        backup.importBackup(pack({...original, 'tables': tables})),
        throwsA(isA<InvalidBackupException>()),
      );
      expect((await db.select(db.notes).get()).single.title, 'Keep me');
    },
  );

  test(
    'legacy backup clears omitted finance tables instead of retaining stale rows',
    () async {
      final legacy = manifest(await backup.exportBackup())
        ..['formatVersion'] = 1;
      final tables = legacy['tables'] as Map;
      for (final name in ['bills', 'recurringTransactions', 'accountTypes']) {
        tables.remove(name);
      }
      await db
          .into(db.bills)
          .insert(
            BillsCompanion.insert(
              name: 'Stale',
              amountMinor: 100,
              dueDate: DateTime(2026),
            ),
          );
      await backup.importBackup(pack(legacy));
      expect(await db.select(db.bills).get(), isEmpty);
    },
  );

  test(
    'malformed rows roll back replacement and unsafe paths are rejected',
    () async {
      await db.into(db.notes).insert(NotesCompanion.insert(title: 'Keep me'));
      final original = manifest(await backup.exportBackup());
      (original['tables'] as Map)['notes'] = [
        {'invalid': true},
      ];
      await expectLater(backup.importBackup(pack(original)), throwsA(anything));
      expect((await db.select(db.notes).get()).single.title, 'Keep me');
      (original['tables'] as Map)['documents'] = [
        {'filePath': '../outside.txt'},
      ];
      await expectLater(
        backup.importBackup(pack(original)),
        throwsA(isA<InvalidBackupException>()),
      );
      expect((await db.select(db.notes).get()).single.title, 'Keep me');
    },
  );
}
