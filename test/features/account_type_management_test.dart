import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';
import 'package:life_manager/features/finance/presentation/screens/account_type_management_screen.dart';

/// The Account types screen had the same two problems the category screen had:
/// its editor was a bare bottom sheet (no × button, no safe-area gap), and the
/// "Add type" button floated over the list with no room below the last row, so
/// that row's delete button could not be tapped.
void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
  });

  tearDown(() => db.close());

  /// A notch-sized top inset, so a sheet that ignores it is visibly wrong.
  const padding = EdgeInsets.only(top: 47, bottom: 34);

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: padding,
              viewPadding: padding,
            ),
            child: child!,
          ),
          home: const AccountTypeManagementScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }


  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('the add and edit sheets use the shared chrome', (tester) async {
    await repo.ensureDefaultAccountTypes();
    await pumpScreen(tester);

    // Add. The default types make a short list, so the dashed row at its end is
    // on screen and has taken the FAB's place.
    await tester.tap(find.text('Add account type'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactEditorSheet), findsOneWidget);
    expect(find.text('New account type'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(CompactEditorSheet)).dy,
      greaterThanOrEqualTo(padding.top),
      reason: 'sheet ran up behind the status bar',
    );
    expect(find.byTooltip('Cancel'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactEditorSheet), findsNothing);

    // Edit.
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Edit account type'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    await disposeCleanly(tester);
  });
}
