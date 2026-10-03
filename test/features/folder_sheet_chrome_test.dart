import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/features/documents/presentation/screens/documents_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The folder sheet was a bare bottom sheet: no × button, no gap below the
/// status bar, and not even scrollable.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// A notch-sized top inset, so a sheet that ignores it is visibly wrong.
  const padding = EdgeInsets.only(top: 47, bottom: 34);

  Future<void> pump(WidgetTester tester, Widget home) async {
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
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }


  testWidgets('the folder sheet uses the shared chrome', (tester) async {
    await pump(tester, const DocumentsScreen());

    await tester.tap(find.byIcon(LucideIcons.folderPlus));
    await tester.pumpAndSettle();

    expect(find.byType(CompactEditorSheet), findsOneWidget);
    expect(find.text('New folder'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(CompactEditorSheet)).dy,
      greaterThanOrEqualTo(padding.top),
      reason: 'sheet ran up behind the status bar',
    );
    expect(find.byTooltip('Cancel'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactEditorSheet), findsNothing);
    await disposeCleanly(tester);
  });
}
