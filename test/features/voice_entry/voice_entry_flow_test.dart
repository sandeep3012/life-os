import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/voice_entry/application/voice_entry_controller.dart';
import 'package:life_manager/features/voice_entry/data/sample_voice_parser.dart';
import 'package:life_manager/features/voice_entry/data/speech_capture.dart';
import 'package:life_manager/features/voice_entry/data/voice_parser.dart';
import 'package:life_manager/features/voice_entry/domain/voice_draft.dart';
import 'package:life_manager/features/voice_entry/presentation/voice_entry_sheet.dart';

class FakeSpeech implements SpeechCapture {
  SpeechTextCallback? _onText;
  List<String> hints = const [];

  void say(String text, [String pending = '']) =>
      _onText?.call(text, pending, done: false);
  void finish(String text) => _onText?.call(text, '', done: true);

  @override
  Future<void> start({
    required SpeechTextCallback onText,
    List<String> hints = const [],
  }) async {
    _onText = onText;
    this.hints = hints;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class FakeParser implements VoiceParser {
  FakeParser(this.options);
  List<Map<String, Object?>> options;
  VoiceRequest? last;
  Object? error;

  @override
  Future<List<VoiceDraft>> parse(VoiceRequest request) async {
    last = request;
    if (error != null) throw error!;
    return [for (final o in options) ?VoiceDraft.fromJson(o)];
  }
}

class QuietNotifications extends NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> cancelTaskReminder(String taskId) async {}
  @override
  Future<void> cancelEventReminder(String eventId) async {}
  @override
  Future<void> cancelHabitReminder(String habitId) async {}
}

final _options = <Map<String, Object?>>[
  {
    'kind': 'expense',
    'summary': '₹250 expense',
    'title': 'Lunch at Subway',
    'amount': 250,
    'account': 'HDFC',
    'category': 'Dining',
  },
  {
    'kind': 'task',
    'summary': 'Task tomorrow',
    'title': 'Lunch with Riya',
    'date': '2026-11-06',
    'time': '13:00',
  },
  {
    'kind': 'event',
    'summary': 'Event',
    'title': 'Team lunch',
    'date': '2026-11-06',
    'time': '13:00',
    'endTime': '14:00',
    'repeat': 'weekly',
    'weekdays': [5],
  },
];

void main() {
  late AppDatabase db;
  late FakeSpeech speech;
  late FakeParser parser;
  late ProviderContainer container;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    speech = FakeSpeech();
    parser = FakeParser(_options);
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: const Value('hdfc'),
        name: 'HDFC Savings',
        type: 'savings',
        balanceMinor: const Value(100000),
        openingBalanceMinor: const Value(100000),
      ),
    );
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: const Value('food'),
        name: 'Dining',
        colorHex: '#E0475A',
      ),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        speechCaptureProvider.overrideWithValue(speech),
        voiceParserProvider.overrideWithValue(parser),
        // Tests run as debug builds, where test mode is on by default.
        voiceTestModeProvider.overrideWith(_TestModeOff.new),
        notificationServiceProvider.overrideWithValue(QuietNotifications()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<VoiceEntryController> heard(String sentence) async {
    final sub = container.listen(voiceEntryControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(voiceEntryControllerProvider.notifier);
    await controller.listen();
    speech.say('spent 250');
    expect(container.read(voiceEntryControllerProvider).text, 'spent 250');
    speech.finish(sentence);
    for (var i = 0; i < 50; i++) {
      if (container.read(voiceEntryControllerProvider).phase !=
          VoicePhase.thinking) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return controller;
  }

  test('speech becomes three options matched to this phone', () async {
    await heard('spent 250 on lunch at Subway from HDFC');
    final state = container.read(voiceEntryControllerProvider);
    expect(state.phase, VoicePhase.choosing);
    expect(state.options, hasLength(3));
    expect(state.options.first.account!.id, 'hdfc');
    expect(state.options.first.category!.id, 'food');

    // The server was told the person's own names, and so was the recogniser.
    expect(parser.last!.accounts, ['HDFC Savings']);
    expect(parser.last!.expenseCategories, contains('Dining'));
    expect(speech.hints, containsAll(['HDFC Savings', 'Dining']));
  });

  test('choosing an expense saves it, moves the balance, and Undo takes it back',
      () async {
    final controller = await heard('spent 250 on lunch');
    final option = container.read(voiceEntryControllerProvider).options.first;

    final saved = await controller.choose(option);
    expect(saved.message, 'Expense added');
    final txn = await db.select(db.transactions).getSingle();
    expect(txn.amountMinor, -25000);
    expect(txn.merchant, 'Lunch at Subway');
    expect((await db.select(db.accounts).getSingle()).balanceMinor, 75000);

    await saved.undo();
    expect(await db.select(db.transactions).get(), isEmpty);
    expect((await db.select(db.accounts).getSingle()).balanceMinor, 100000);
  });

  test('a task and a repeating event save, and Undo removes them whole', () async {
    final controller = await heard('lunch tomorrow at one');
    final options = container.read(voiceEntryControllerProvider).options;

    final task = await controller.choose(options[1]);
    final row = await db.select(db.tasks).getSingle();
    expect(row.title, 'Lunch with Riya');
    expect(row.dueDate, DateTime(2026, 11, 6, 13));
    expect(row.reminderEnabled, isTrue, reason: 'a time was said');
    await task.undo();
    expect(await db.select(db.tasks).get(), isEmpty);

    final event = await controller.choose(options[2]);
    expect(event.message, 'Repeating event added');
    final events = await db.select(db.events).get();
    expect(events.length, greaterThan(1));
    expect(events.every((e) => e.startTime.weekday == DateTime.friday), isTrue);
    await event.undo();
    expect(await db.select(db.events).get(), isEmpty);
  });

  test('a habit saves and Undo deletes it', () async {
    parser.options = [
      {
        'kind': 'habit',
        'title': 'Gym',
        'time': '07:00',
        'repeat': 'weekly',
        'weekdays': [1, 4],
      },
    ];
    final controller = await heard('gym every monday and thursday at 7');
    final option = container.read(voiceEntryControllerProvider).options.single;
    final saved = await controller.choose(option);
    final habit = await db.select(db.habits).getSingle();
    expect(habit.name, 'Gym');
    expect(habit.reminderHour, 7);
    await saved.undo();
    expect(await db.select(db.habits).get(), isEmpty);
  });

  test('nothing heard, or a server problem, says so', () async {
    await heard('');
    expect(container.read(voiceEntryControllerProvider).phase, VoicePhase.error);

    parser.error = const VoiceParseException(
      "You've reached today's voice entry limit. Try again tomorrow.",
    );
    await heard('add milk to the list');
    final state = container.read(voiceEntryControllerProvider);
    expect(state.phase, VoicePhase.error);
    expect(state.message, contains('limit'));
    expect(state.text, 'add milk to the list', reason: 'kept for Try again');
  });

  testWidgets('asks once, then shows the options and saves the one tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showVoiceEntrySheet(context, ref),
                child: const Text('speak'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('speak'));
    await tester.pumpAndSettle();
    expect(find.text('Add things by voice'), findsOneWidget);
    await tester.tap(find.text('Turn on'));
    // Saving the consent and reading the accounts are real database I/O,
    // outside the test's fake clock.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Listening…'), findsOneWidget);

    speech.finish('spent 250 on lunch');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Which one did you mean?'), findsOneWidget);
    expect(find.text('Lunch at Subway'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Lunch at Subway'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('Which one did you mean?'), findsNothing);
    expect(
      (await tester.runAsync(() => db.select(db.transactions).get()))!,
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a detail can be changed on the card before saving', (
    tester,
  ) async {
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: const Value('errands'),
        name: 'Errands',
        colorHex: '#000000',
        kind: const Value(plannerCategoryKind),
      ),
    );
    tester.view.physicalSize = const Size(392, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: VoiceEntrySheet()),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    speech.finish('lunch with riya tomorrow at one');
    await settle();
    expect(find.text('Which one did you mean?'), findsOneWidget);

    // The task came back without a category: it's offered, not hidden.
    final addCategory = find.text('+ Category');
    expect(addCategory, findsWidgets);
    await tester.ensureVisible(addCategory.first);
    await tester.tap(addCategory.first);
    await settle();
    await tester.tap(find.text('Errands'));
    await settle();
    expect(find.text('Errands'), findsOneWidget);

    await tester.tap(find.text('Lunch with Riya'));
    await settle();
    final task = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
    expect(task.categoryId, 'errands');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _TestModeOff extends VoiceTestMode {
  @override
  bool build() => false;
}
