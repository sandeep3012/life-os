import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/features/sync/application/sync_providers.dart';
import 'package:life_manager/features/sync/presentation/sync_screen.dart';

import 'sync_fakes.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<void> pump(WidgetTester tester, List overrides) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides],
        child: MaterialApp(theme: AppTheme.light(), home: const SyncScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> disposeCleanly(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('a build without keys says sync is unavailable', (tester) async {
    await pump(tester, [
      syncSessionProvider.overrideWithValue(null),
      syncBackendProvider.overrideWithValue(null),
    ]);
    expect(find.text('Sync isn\'t available in this build'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeCleanly(tester);
  });

  testWidgets('signed out, it offers sign in and sign up', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await pump(tester, [
      appDatabaseProvider.overrideWithValue(db),
      syncSessionProvider.overrideWithValue(FakeSession()),
      syncBackendProvider.overrideWithValue(FakeSyncServer().client()),
      syncKeyStoreProvider.overrideWithValue(MemoryKeyStore()),
    ]);
    expect(find.text('Your data on all your phones'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeCleanly(tester);
  });

  testWidgets('the recovery key must be marked as saved before continuing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showRecoveryKeySheet(context, 'LOS-ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-23'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('LOS-ABCD-EFGH-JKMN-PQRS-TVWX-YZ01-23'), findsOneWidget);

    final cont = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(cont).onPressed, isNull);
    await tester.tap(find.text('I\'ve saved my recovery key'));
    await tester.pump();
    expect(tester.widget<FilledButton>(cont).onPressed, isNotNull);
    await tester.tap(cont);
    await tester.pumpAndSettle();
    expect(find.text('Your recovery key'), findsNothing);
  });
}
