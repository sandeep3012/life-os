import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/notes/presentation/screens/notes_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Widget buildApp() {
    return ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(theme: AppTheme.light(), home: const NotesScreen()),
    );
  }

  testWidgets('creating a note shows it in the grid, editing updates it', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('No notes yet — add one to get started.'), findsOneWidget);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Grocery list');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), 'Milk, eggs, spinach');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Grocery list'), findsOneWidget);
    expect(find.textContaining('Milk, eggs, spinach'), findsOneWidget);

    await tester.tap(find.text('Grocery list'));
    await tester.pumpAndSettle();

    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'Grocery list (updated)');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Grocery list (updated)'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('tagging a note shows the tag chip and filters the list', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Tagged note');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tag name'), 'Work');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsWidgets);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Filter the list by the "Work" tag chip.
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Tagged note'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
