import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/documents/application/documents_providers.dart';
import 'package:life_manager/features/documents/data/documents_repository.dart';
import 'package:life_manager/features/finance/application/finance_providers.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/goals/application/goals_providers.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';
import 'package:life_manager/features/habits/application/habits_providers.dart';
import 'package:life_manager/features/habits/data/habits_repository.dart';
import 'package:life_manager/features/notes/application/notes_providers.dart';
import 'package:life_manager/features/notes/data/notes_repository.dart';
import 'package:life_manager/features/search/application/search_providers.dart';
import 'package:life_manager/features/search/domain/search_result.dart';
import 'package:life_manager/features/tasks/application/tasks_providers.dart';
import 'package:life_manager/features/tasks/data/tasks_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);
  final String tempPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;
}

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late FileStorageService storage;
  late NotesRepository notesRepo;
  late DocumentsRepository docsRepo;
  late FinanceRepository financeRepo;
  late TasksRepository tasksRepo;
  late HabitsRepository habitsRepo;
  late GoalsRepository goalsRepo;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('e2e_notes_docs_test');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    storage = FileStorageService();
    notesRepo = NotesRepository(db);
    docsRepo = DocumentsRepository(db, storage);
    financeRepo = FinanceRepository(db, storage);
    tasksRepo = TasksRepository(db);
    habitsRepo = HabitsRepository(db);
    goalsRepo = GoalsRepository(db);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        fileStorageServiceProvider.overrideWithValue(storage),
        notesRepositoryProvider.overrideWithValue(notesRepo),
        documentsRepositoryProvider.overrideWithValue(docsRepo),
        financeRepositoryProvider.overrideWithValue(financeRepo),
        tasksRepositoryProvider.overrideWithValue(tasksRepo),
        habitsRepositoryProvider.overrideWithValue(habitsRepo),
        goalsRepositoryProvider.overrideWithValue(goalsRepo),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('E2E Notes, Documents & Multi-Entity Global Search', () {
    test('shared folders table preserves scope isolation between notes and documents', () async {
      // 1. Create identically-named folders in notes and documents scopes
      await notesRepo.createFolder('Tax & Finance');
      await docsRepo.createFolder('Tax & Finance');

      // Keep streams listened
      final notesFoldersSub = container.listen(noteFoldersProvider, (_, _) {});
      final docsFoldersSub = container.listen(documentFoldersProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      final notesFolders = container.read(noteFoldersProvider).value ?? [];
      final docsFolders = container.read(documentFoldersProvider).value ?? [];

      expect(notesFolders, hasLength(1));
      expect(notesFolders.first.scope, 'notes');
      expect(notesFolders.first.name, 'Tax & Finance');

      expect(docsFolders, hasLength(1));
      expect(docsFolders.first.scope, 'documents');
      expect(docsFolders.first.name, 'Tax & Finance');

      expect(notesFolders.first.id != docsFolders.first.id, isTrue);

      notesFoldersSub.close();
      docsFoldersSub.close();
    });

    test('documents import, file persistence, and deletion file clean-up', () async {
      // 1. Create a dummy file to import
      final sourceFile = File('${tempDir.path}/test_contract.pdf')
        ..writeAsStringSync('%PDF-1.4 Mock contract content for testing');

      await docsRepo.importAndCreateDocument(
        source: sourceFile,
        originalName: 'Apartment Lease.pdf',
        title: 'Apartment Lease 2026',
      );

      final docs = await docsRepo.watchDocuments().first;
      expect(docs, hasLength(1));
      final doc = docs.first;
      expect(doc.title, 'Apartment Lease 2026');
      expect(doc.filePath, isNotEmpty);

      // Verify file was imported into storage
      final storedFile = await storage.absoluteFile(doc.filePath);
      expect(await storedFile.exists(), isTrue);

      // 2. Delete document -> verify physical file is unlinked
      await docsRepo.deleteDocument(doc);
      final docsAfterDelete = await docsRepo.watchDocuments().first;
      expect(docsAfterDelete, isEmpty);
      expect(await storedFile.exists(), isFalse);
    });

    test('global search across 9 entity types with case-insensitivity and special query characters', () async {
      // Keep all stream providers actively listened
      final subNotes = container.listen(notesListProvider, (_, _) {});
      final subTasks = container.listen(allTasksProvider, (_, _) {});
      final subGoals = container.listen(goalsListProvider, (_, _) {});
      final subTxns = container.listen(transactionsProvider, (_, _) {});
      final subHabits = container.listen(habitsListProvider, (_, _) {});
      final subSearch = container.listen(searchResultsProvider, (_, _) {});
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Seed entities across different modules
      await notesRepo.createNote(
        title: 'Project Roadmap 2026',
        body: 'Contains details on [Vite+React] and Flutter architecture.',
      );

      await habitsRepo.createHabit('Read Architecture Specs');

      await tasksRepo.createTask(
        title: 'Fix issue with [Vite+React] build',
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );

      await goalsRepo.createGoal(
        title: 'Master Flutter and [Vite+React]',
      );

      final account = await db.into(db.accounts).insertReturning(
        AccountsCompanion.insert(name: 'Checking Main', type: 'checking'),
      );

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: account.id,
          merchant: 'React & Vite Summit Ticket',
          amountMinor: -450000,
          date: DateTime.now(),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Search query: "vite" (Testing case-insensitivity and substring matching across modules)
      container.read(searchQueryProvider.notifier).set('vite');
      await Future.delayed(const Duration(milliseconds: 50));
      final searchResults = container.read(searchResultsProvider);

      expect(searchResults.length, greaterThanOrEqualTo(4));
      final types = searchResults.map((r) => r.type).toSet();
      expect(types, contains(SearchResultType.note));
      expect(types, contains(SearchResultType.task));
      expect(types, contains(SearchResultType.goal));
      expect(types, contains(SearchResultType.transaction));

      // 3. Search query: empty or whitespace -> returns empty list
      container.read(searchQueryProvider.notifier).set('   ');
      expect(container.read(searchResultsProvider), isEmpty);

      // 4. Search query: non-matching query
      container.read(searchQueryProvider.notifier).set('xyznonexistentterm');
      expect(container.read(searchResultsProvider), isEmpty);

      subNotes.close();
      subTasks.close();
      subGoals.close();
      subTxns.close();
      subHabits.close();
      subSearch.close();
    });
  });
}
