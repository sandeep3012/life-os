// Makes the phone screenshots for the store listing, with no phone attached:
//
//     flutter test tool/store_screenshots/store_screenshots_test.dart
//
// It runs the real app against an in-memory database filled with the demo
// data, opens each screen and saves it to store/google-play/screenshots/.
// Run it again whenever a screen changes. It lives outside test/ so the
// normal suite (and CI) never runs it.
//
// Google Play wants a side no longer than twice the other, so the frame is
// 1080 x 2160 (a 400 x 800 point phone), not a modern 20:9 screen.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_manager/app/app.dart';
import 'package:life_manager/app/preview_features.dart';
import 'package:life_manager/app/router/route_paths.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_mode.dart';
import 'package:life_manager/core/services/demo_data_service.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/home/presentation/screens/home_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _width = 1080.0;
const _height = 2160.0;
const _pixelRatio = 2.7;
const _outDir = 'store/google-play/screenshots';

/// Screens to capture, in the order they should appear on the listing.
const _shots = <(String, String)>[
  ('01-home', RoutePaths.home),
  ('02-money', RoutePaths.finance),
  ('03-spending', RoutePaths.spendAnalyzer),
  ('04-habits', RoutePaths.plannerHabits),
  ('05-tasks', RoutePaths.tasksHabits),
  ('06-calendar', RoutePaths.calendar),
  ('07-goals', RoutePaths.goals),
  ('08-notes', RoutePaths.notes),
  ('09-documents', RoutePaths.documents),
];

class _QuietNotifications extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleDailyHabitReminder({
    int hour = 20,
    int minute = 0,
  }) async {}

  @override
  Future<void> cancelDailyHabitReminder() async {}

  @override
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required DateTime dueDate,
    ReminderMode mode = ReminderMode.notification,
  }) async {}

  @override
  Future<void> cancelTaskReminder(String taskId) async {}
}

class _TempPaths extends PathProviderPlatform {
  _TempPaths(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getTemporaryPath() async => path;
}

/// Tests draw every letter as a box unless the real fonts are loaded; this
/// loads all of them, the icon font included, from the app's own manifest.
Future<void> _loadFonts() async {
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// The demo data is made for testing, so it carries deliberate extremes — a
/// twelve-lakh payout, a home loan, a one-rupee payment — and the parts of
/// the app a release build hides. A store page should show an ordinary month.
Future<void> _tidyForTheStore(AppDatabase db) async {
  const oddAccounts =
      "'demo-account-loan', 'demo-account-closed', 'demo-account-foreign'";
  for (final sql in [
    "DELETE FROM transactions WHERE account_id IN ($oddAccounts) OR id IN ("
        "'demo-txn-huge', 'demo-txn-closed-account', 'demo-txn-emi', "
        "'demo-txn-tiny', 'demo-txn-uncategorised', 'demo-txn-other-mode', "
        "'demo-txn-foreign')",
    'DELETE FROM accounts WHERE id IN ($oddAccounts)',
    "UPDATE accounts SET name = 'Salary Account' "
        "WHERE id = 'demo-account-checking'",
    // An empty note and one about this app's own release.
    "DELETE FROM notes "
        "WHERE title IN ('Untitled thought', 'Standup talking points')",
    "UPDATE tasks SET description = NULL WHERE description LIKE 'Demo task%'",
    // Health and Learn aren't in release builds.
    'DELETE FROM exercise_set_logs',
    'DELETE FROM workout_logs',
    'DELETE FROM exercises',
    'DELETE FROM workout_days',
    'DELETE FROM medication_logs',
    'DELETE FROM medications',
    'DELETE FROM learn_notes',
    'DELETE FROM learn_books',
  ]) {
    await db.customStatement(sql);
  }
}

/// Lets a screen load and finish arriving. Not `pumpAndSettle`: some
/// screens carry an animation that never ends, and that would wait for
/// ever. Streams answer in real time, entrance animations in fake time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }
}

void main() {
  testWidgets('store screenshots', (tester) async {
    await tester.runAsync(_loadFonts);
    // Tests flatten shadows into hard-edged blocks by default. Put back at
    // the end of the body: the framework checks it before tear-downs run.
    debugDisableShadows = false;

    final temp = await tester.runAsync(
      () => Directory.systemTemp.createTemp('personalos_shots'),
    );
    PathProviderPlatform.instance = _TempPaths(temp!.path);

    tester.view
      ..physicalSize = const Size(_width, _height)
      ..devicePixelRatio = _pixelRatio
      // Room where the status bar and the gesture bar would be.
      ..padding = const FakeViewPadding(top: 76, bottom: 44)
      ..viewPadding = const FakeViewPadding(top: 76, bottom: 44);
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() async {
      // Someone past the welcome screens and the first-run tips.
      await db
          .into(db.appSettings)
          .insert(
            const AppSettingsCompanion(
              id: Value(0),
              onboardingCompleted: Value(true),
              toursSeen: Value('home,hold_to_speak'),
            ),
          );
      await DemoDataService(db).generate(months: 6);
      await _tidyForTheStore(db);
    });

    final frame = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            notificationServiceProvider.overrideWithValue(
              _QuietNotifications(),
            ),
            // What a release build shows.
            previewFeaturesProvider.overrideWithValue(false),
          ],
          child: const PersonalOSApp(),
        ),
      ),
    );
    await _settle(tester);

    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    final out = Directory(_outDir)..createSync(recursive: true);

    for (final (name, path) in _shots) {
      // Side-menu screens open on top of the current tab; start them from
      // Home so the bottom bar doesn't highlight whichever tab came before.
      if (path.startsWith('${RoutePaths.more}/')) {
        router.go(RoutePaths.home);
        await tester.pump(const Duration(milliseconds: 50));
      }
      router.go(path);
      await _settle(tester);
      if (path == RoutePaths.calendar) {
        // Nudge the day's list up: the calendar folds to one week and the
        // agenda gets the room.
        await tester.dragFrom(const Offset(200, 640), const Offset(0, -40));
        await _settle(tester);
      }

      final boundary =
          frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: _pixelRatio);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('${out.path}/$name.png').writeAsBytesSync(bytes!);
      // ignore: avoid_print
      print('saved ${out.path}/$name.png');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    debugDisableShadows = true;
  }, timeout: const Timeout(Duration(minutes: 2)));
}
