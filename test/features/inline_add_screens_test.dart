import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/core/widgets/inline_add_button.dart';
import 'package:life_manager/features/documents/presentation/screens/folder_documents_screen.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/finance/presentation/screens/account_type_management_screen.dart';
import 'package:life_manager/features/finance/presentation/screens/bills_screen.dart';
import 'package:life_manager/features/finance/presentation/screens/category_management_screen.dart';
import 'package:life_manager/features/finance/presentation/screens/recurring_transactions_screen.dart';
import 'package:life_manager/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:life_manager/features/notes/presentation/screens/notes_screen.dart';
import 'package:life_manager/features/tasks/presentation/screens/planner_categories_screen.dart';

/// Every list screen that has a floating "add" button now ends its list with
/// the dashed add row and shows only one of the two at a time: the dashed row
/// while it is on screen (the end of the list), the FAB once it has scrolled
/// away — the rule Tasks, Habits, Goals, Health and Learn already follow.
class _Screen {
  const _Screen({
    required this.name,
    required this.build,
    required this.seed,
    required this.opensOnTap,
  });

  final String name;
  final Widget Function() build;

  /// Fills the screen with [count] rows.
  final Future<void> Function(AppDatabase db, FinanceRepository repo, int count)
  seed;

  /// True once tapping the dashed row has opened its add flow.
  final bool Function() opensOnTap;
}

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
  });

  tearDown(() => db.close());

  Future<void> seedAccount() => repo.createAccount(name: 'Cash', type: 'Cash');

  final screens = <_Screen>[
    _Screen(
      name: 'categories',
      build: () => const CategoryManagementScreen(),
      seed: (db, repo, n) async {
        for (var i = 1; i <= n; i++) {
          await repo.createCategory(
            name: 'Category $i',
            icon: 'label',
            colorHex: '#2E9E63',
          );
        }
      },
      opensOnTap: () => find.byType(CompactEditorSheet).evaluate().isNotEmpty,
    ),
    _Screen(
      name: 'account types',
      build: () => const AccountTypeManagementScreen(),
      seed: (db, repo, n) async {
        for (var i = 1; i <= n; i++) {
          await repo.createAccountType(name: 'Type $i', icon: 'label');
        }
      },
      opensOnTap: () => find.byType(CompactEditorSheet).evaluate().isNotEmpty,
    ),
    _Screen(
      name: 'bills',
      build: () => const BillsScreen(),
      seed: (db, repo, n) async {
        await seedAccount();
        final account = (await db.select(db.accounts).get()).single;
        for (var i = 1; i <= n; i++) {
          await repo.createBill(
            name: 'Bill $i',
            accountId: account.id,
            amountMinor: 10000 * i,
            dueDate: DateTime(2027, 1, i),
          );
        }
      },
      opensOnTap: () => find.byType(CompactEditorSheet).evaluate().isNotEmpty,
    ),
    _Screen(
      name: 'recurring transactions',
      build: () => const RecurringTransactionsScreen(),
      seed: (db, repo, n) async {
        await seedAccount();
        final account = (await db.select(db.accounts).get()).single;
        for (var i = 1; i <= n; i++) {
          await repo.createRecurringTransaction(
            accountId: account.id,
            merchant: 'Item $i',
            amountMinor: -10000 * i,
            frequency: 'monthly',
            startDate: DateTime(2027, 1, i),
          );
        }
      },
      opensOnTap: () => find.byType(CompactEditorSheet).evaluate().isNotEmpty,
    ),
    _Screen(
      name: 'task categories',
      build: () => const PlannerCategoriesScreen(kind: 'task'),
      seed: (db, repo, n) async {
        for (var i = 1; i <= n; i++) {
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  name: 'Task category $i',
                  colorHex: '#2E9E63',
                  kind: const Value('task'),
                ),
              );
        }
      },
      opensOnTap: () => find.byType(CompactEditorSheet).evaluate().isNotEmpty,
    ),
    _Screen(
      name: 'notes',
      build: () => const NotesScreen(),
      seed: (db, repo, n) async {
        for (var i = 1; i <= n; i++) {
          await db
              .into(db.notes)
              .insert(NotesCompanion.insert(title: 'Note $i'));
        }
      },
      opensOnTap: () => find.byType(NoteEditorScreen).evaluate().isNotEmpty,
    ),
    _Screen(
      name: 'folder documents',
      build: () =>
          const FolderDocumentsScreen(folderId: 'folder-1', folderName: 'Docs'),
      seed: (db, repo, n) async {
        await db
            .into(db.folders)
            .insert(
              FoldersCompanion.insert(
                id: const Value('folder-1'),
                name: 'Docs',
                scope: 'documents',
              ),
            );
        for (var i = 1; i <= n; i++) {
          await db
              .into(db.documents)
              .insert(
                DocumentsCompanion.insert(
                  title: 'Doc $i',
                  filePath: 'docs/doc$i.pdf',
                  mimeType: 'application/pdf',
                  folderId: const Value('folder-1'),
                ),
              );
        }
      },
      opensOnTap: () => find.byType(BottomSheet).evaluate().isNotEmpty,
    ),
  ];

  Future<void> pump(WidgetTester tester, _Screen screen) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(theme: AppTheme.light(), home: screen.build()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The screen's main list: the vertical scrollable (Notes also has horizontal
  /// chip rows above it).
  ScrollPosition listPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.vertical,
            )
            .first,
      )
      .position;

  /// Jumps to the very end. Rows vary in height, so the list's extent is only
  /// an estimate until they've all been built — keep jumping until it stops
  /// growing. (A big drag isn't reliable: events that leave the test surface
  /// are dropped.)
  Future<void> scrollToEnd(WidgetTester tester) async {
    final position = listPosition(tester);
    for (var i = 0; i < 20; i++) {
      final before = position.maxScrollExtent;
      position.jumpTo(before);
      await tester.pumpAndSettle();
      if (position.maxScrollExtent == before) break;
    }
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  final fab = find.byType(FloatingActionButton);
  final inlineAdd = find.byType(InlineAddButton);

  for (final screen in screens) {
    group(screen.name, () {
      testWidgets(
        'shows the FAB, not the dashed row, at the top of a long list',
        (tester) async {
          await screen.seed(db, repo, 15);
          await pump(tester, screen);

          expect(fab, findsOneWidget);
          expect(inlineAdd, findsNothing);
          await disposeCleanly(tester);
        },
      );

      testWidgets('swaps the FAB for the dashed row at the end of the list', (
        tester,
      ) async {
        await screen.seed(db, repo, 15);
        await pump(tester, screen);

        await scrollToEnd(tester);
        expect(inlineAdd, findsOneWidget);
        expect(fab, findsNothing, reason: 'two add buttons on screen at once');

        // Scrolling back up brings the FAB back.
        listPosition(tester).jumpTo(0);
        await tester.pumpAndSettle();
        expect(fab, findsOneWidget);
        expect(inlineAdd, findsNothing);
        await disposeCleanly(tester);
      });

      testWidgets('tapping the dashed row opens the add flow', (tester) async {
        await screen.seed(db, repo, 15);
        await pump(tester, screen);
        await scrollToEnd(tester);

        await tester.tap(inlineAdd);
        await tester.pumpAndSettle();

        expect(screen.opensOnTap(), isTrue);
        await disposeCleanly(tester);
      });

      testWidgets('a short list shows the dashed row straight away', (
        tester,
      ) async {
        await screen.seed(db, repo, 2);
        await pump(tester, screen);

        expect(inlineAdd, findsOneWidget);
        expect(fab, findsNothing);
        await disposeCleanly(tester);
      });

      testWidgets('an empty list keeps the FAB', (tester) async {
        await pump(tester, screen);

        expect(inlineAdd, findsNothing);
        expect(fab, findsOneWidget);
        await disposeCleanly(tester);
      });
    });
  }
}
