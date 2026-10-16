import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/widgets/undo_snack_bar.dart';

void main() {
  testWidgets('the Undo snackbar goes away by itself', (tester) async {
    var undone = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showUndoSnackBar(
                ScaffoldMessenger.of(context),
                message: 'Task deleted',
                onUndo: () async => undone = true,
              ),
              child: const Text('delete'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('delete'));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);

    await tester.pump(undoWindow + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsNothing);
    expect(undone, isFalse);
  });
}
