import 'dart:io';

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
import 'package:life_manager/features/documents/presentation/screens/document_viewer_screen.dart';
import 'package:life_manager/features/documents/presentation/screens/folder_documents_screen.dart';

/// Points every document at a file that isn't there — like one that
/// arrived through sync without its file.
class _NoFiles extends FileStorageService {
  @override
  Future<File> absoluteFile(String relativePath) async =>
      File('${Directory.systemTemp.path}/lifeos-missing/$relativePath');
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) async {
    await db
        .into(db.folders)
        .insert(
          FoldersCompanion.insert(
            id: const Value('work'),
            name: 'Work',
            scope: 'documents',
          ),
        );
    await db
        .into(db.documents)
        .insert(
          DocumentsCompanion.insert(
            title: 'Offer letter',
            filePath: 'docs/offer.pdf',
            mimeType: 'application/pdf',
            folderId: const Value('work'),
          ),
        );
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
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          fileStorageServiceProvider.overrideWithValue(_NoFiles()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('tapping a document opens it, not its details', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Offer letter'));
    // Checking the file is real I/O, outside the test's fake clock.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentViewerScreen), findsOneWidget);
    expect(find.textContaining("isn't on this phone"), findsOneWidget);
    expect(find.byTooltip('Edit details'), findsOneWidget);
    await disposeCleanly(tester);
  });

  testWidgets('a long press opens the details to edit', (tester) async {
    await pump(tester);

    await tester.longPress(find.text('Offer letter'));
    await tester.pumpAndSettle();

    expect(find.byType(DocumentViewerScreen), findsNothing);
    expect(find.text('Offer letter'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
    await disposeCleanly(tester);
  });
}
