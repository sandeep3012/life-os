import 'dart:io';

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

  test('export then import restores rows and document files identically', () async {
    // Seed one row per representative table, including a real document file.
    final category = await db.into(db.categories).insertReturning(
      CategoriesCompanion.insert(name: 'Dining', colorHex: '#E0475A'),
    );
    final account = await db.into(db.accounts).insertReturning(
      AccountsCompanion.insert(name: 'Checking', type: 'checking', balanceMinor: const Value(50000)),
    );
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        accountId: account.id,
        categoryId: Value(category.id),
        merchant: 'Swiggy',
        amountMinor: -6400,
        date: DateTime(2026, 7, 26),
      ),
    );
    final habit = await db.into(db.habits).insertReturning(
      HabitsCompanion.insert(name: 'Morning workout'),
    );
    await db.into(db.habitLogs).insert(
      HabitLogsCompanion.insert(habitId: habit.id, date: DateTime(2026, 7, 25)),
    );
    final goal = await db.into(db.goals).insertReturning(
      GoalsCompanion.insert(title: 'Emergency Fund', targetValue: const Value(200000)),
    );
    await db.into(db.goalLinks).insert(
      GoalLinksCompanion.insert(goalId: goal.id, linkedType: 'account', linkedId: account.id),
    );

    final folder = await db.into(db.folders).insertReturning(
      FoldersCompanion.insert(name: 'Receipts', scope: 'documents'),
    );
    final source = File('${tempDir.path}/rent.txt')..writeAsStringSync('receipt contents');
    final stored = await storage.importFile(source, originalName: 'rent_receipt.txt');
    await db.into(db.documents).insert(
      DocumentsCompanion.insert(
        title: 'Rent receipt',
        filePath: stored.relativePath,
        mimeType: stored.mimeType,
        folderId: Value(folder.id),
      ),
    );

    final zipBytes = await backup.exportBackup();
    expect(zipBytes, isNotEmpty);

    // Wipe everything, then restore from the exported bytes.
    await db.delete(db.transactions).go();
    await db.delete(db.accounts).go();
    await db.delete(db.categories).go();
    await db.delete(db.habitLogs).go();
    await db.delete(db.habits).go();
    await db.delete(db.goalLinks).go();
    await db.delete(db.goals).go();
    await db.delete(db.documents).go();
    await db.delete(db.folders).go();
    await storage.deleteFile(stored.relativePath);

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await (await storage.absoluteFile(stored.relativePath)).exists(), isFalse);

    await backup.importBackup(zipBytes);

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

    final restoredDocs = await db.select(db.documents).get();
    expect(restoredDocs.single.title, 'Rent receipt');

    final restoredFile = await storage.absoluteFile(stored.relativePath);
    expect(await restoredFile.exists(), isTrue);
    expect(await restoredFile.readAsString(), 'receipt contents');
  });

  test('importBackup rejects a file that is not a LifeOS backup', () async {
    final notABackup = File('${tempDir.path}/not-a-backup.zip')
      ..writeAsBytesSync([1, 2, 3, 4]);

    expect(
      () => backup.importBackup(notABackup.readAsBytesSync()),
      throwsA(isA<InvalidBackupException>()),
    );
  });
}
