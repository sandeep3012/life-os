import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/widgets/compact_editor_sheet.dart';
import 'package:life_manager/features/tasks/application/tasks_providers.dart';
import 'package:life_manager/features/tasks/presentation/widgets/task_tile.dart';
import 'package:life_manager/features/tasks/presentation/widgets/quick_add_task_sheet.dart';
import 'package:life_manager/features/habits/presentation/widgets/quick_add_habit_sheet.dart';

void main() {
  testWidgets('task body opens details while checkbox only changes completion', (tester) async {
    var opened = 0;
    var toggled = 0;
    final task = Task(id: 't', title: 'Read a book', priority: 'medium', status: 'open',
      reminderEnabled: false, reminderMode: 'notification', createdAt: DateTime(2026));
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: Scaffold(body: TaskTile(
      task: task, onOpen: () => opened++, onToggle: () => toggled++, onDelete: () {}))));
    await tester.tap(find.text('Read a book'));
    expect(opened, 1);
    expect(toggled, 0);
    await tester.tap(find.byTooltip('Mark complete'));
    expect(opened, 1);
    expect(toggled, 1);
  });

  testWidgets('task reminder is visible, opt-in, and date toggle does not enable it', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      taskCategoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
    ], child: MaterialApp(home: Scaffold(appBar: AppBar(title: const Text('Tasks')),
      body: Builder(builder: (context) => TextButton(onPressed: () => showQuickAddTaskSheet(context), child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final reminder = find.widgetWithText(SwitchListTile, 'Remind me');
    expect(tester.widget<SwitchListTile>(reminder).value, isFalse);
    expect(tester.widget<SwitchListTile>(reminder).onChanged, isNull);
    final date = find.widgetWithText(SwitchListTile, 'Date and time');
    await tester.ensureVisible(date);
    await tester.tap(date);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(reminder).value, isFalse);
    expect(tester.widget<SwitchListTile>(reminder).onChanged, isNotNull);
    final description = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Description (optional)');
    expect(tester.widget<TextField>(description).maxLines, 1);
    expect(tester.getTopLeft(find.byType(CompactEditorSheet)).dy, greaterThanOrEqualTo(kToolbarHeight));
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactEditorSheet), findsNothing);
  });

  testWidgets('habit sheet has compact description and visible cancel control', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => TextButton(onPressed: () => showQuickAddHabitSheet(context, categories: []), child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final description = find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == 'Description (optional)');
    expect(tester.widget<TextField>(description).maxLines, 1);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CompactEditorSheet), findsNothing);
  });
}
