import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/documents/data/documents_repository.dart';
import 'package:life_manager/features/documents/domain/folder_tree.dart';
import 'package:life_manager/features/documents/presentation/screens/folder_documents_screen.dart';

/// Folders inside folders: created from a folder's own screen, shown there
/// rather than at the top level, and never taking contents down on delete.
void main() {
  late AppDatabase db;
  late DocumentsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DocumentsRepository(db, FileStorageService());
  });
  tearDown(() => db.close());

  Future<void> folder(String id, String name, {String? parent}) => db
      .into(db.folders)
      .insert(
        FoldersCompanion.insert(
          id: Value(id),
          name: name,
          scope: 'documents',
          parentFolderId: Value(parent),
        ),
      );

  Future<void> doc(String title, String folderId) => db
      .into(db.documents)
      .insert(
        DocumentsCompanion.insert(
          title: title,
          filePath: 'docs/$title.pdf',
          mimeType: 'application/pdf',
          folderId: Value(folderId),
        ),
      );

  Future<List<Folder>> folders() => db.select(db.folders).get();

  group('repository', () {
    test('creates a folder inside another', () async {
      await folder('work', 'Work');
      await repo.createFolder('Contracts', parentFolderId: 'work');
      final contracts = (await folders()).firstWhere(
        (f) => f.name == 'Contracts',
      );
      expect(contracts.parentFolderId, 'work');
    });

    test('deleting a folder moves what was inside up a level', () async {
      await folder('work', 'Work');
      await folder('contracts', 'Contracts', parent: 'work');
      await folder('2026', '2026', parent: 'contracts');
      await doc('NDA', 'contracts');

      await repo.deleteFolder('contracts');

      final remaining = await folders();
      expect(remaining.map((f) => f.id), unorderedEquals(['work', '2026']));
      expect(
        remaining.firstWhere((f) => f.id == '2026').parentFolderId,
        'work',
      );
      final nda = await db.select(db.documents).getSingle();
      expect(nda.folderId, 'work');
    });
  });

  group('FolderTree', () {
    test('paths and tree order', () async {
      await folder('home', 'Home');
      await folder('work', 'Work');
      await folder('w26', '2026', parent: 'work');
      await folder('h26', '2026', parent: 'home');
      final all = await folders();

      expect(FolderTree.pathOf(all, 'w26'), 'Work / 2026');
      expect(FolderTree.childrenOf(all, null).map((f) => f.name), [
        'Home',
        'Work',
      ]);
      expect(FolderTree.flattened(all).map((f) => f.id), [
        'home',
        'h26',
        'work',
        'w26',
      ]);
    });
  });

  testWidgets('a folder shows its sub-folders and makes new ones', (
    tester,
  ) async {
    await folder('work', 'Work');
    await folder('contracts', 'Contracts', parent: 'work');
    await doc('NDA', 'contracts');
    await doc('Offer letter', 'work');

    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/f',
      routes: [
        GoRoute(
          path: '/f',
          builder: (context, state) =>
              const FolderDocumentsScreen(folderId: 'work', folderName: 'Work'),
        ),
        GoRoute(
          path: '/more/documents/folder/:id',
          builder: (context, state) => FolderDocumentsScreen(
            folderId: state.pathParameters['id']!,
            folderName: state.uri.queryParameters['name'] ?? '',
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Contracts'), findsOneWidget);
    expect(find.text('1 document'), findsOneWidget);
    expect(find.text('Offer letter'), findsOneWidget);

    // New folder from the app bar lands inside this folder.
    await tester.tap(find.byTooltip('New folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Payslips');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create folder'));
    await tester.pumpAndSettle();
    final payslips = (await folders()).firstWhere((f) => f.name == 'Payslips');
    expect(payslips.parentFolderId, 'work');
    // Let the save confirmation finish before leaving.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Payslips'), findsOneWidget);

    // Opening a sub-folder shows where it lives.
    await tester.tap(find.text('Contracts'));
    await tester.pumpAndSettle();
    expect(find.text('In Work'), findsOneWidget);
    expect(find.text('NDA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
