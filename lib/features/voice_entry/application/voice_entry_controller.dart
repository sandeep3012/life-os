import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../finance/application/finance_providers.dart';
import '../../finance/data/finance_repository.dart';
import '../../settings/application/settings_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../data/speech_capture.dart';
import '../data/voice_parser.dart';
import '../domain/voice_draft.dart';
import 'category_memory.dart';
import 'voice_draft_saver.dart';

enum VoicePhase { idle, listening, thinking, choosing, error }

class VoiceEntryState {
  const VoiceEntryState({
    this.phase = VoicePhase.idle,
    this.text = '',
    this.pending = '',
    this.options = const [],
    this.message,
    this.accounts = const [],
    this.categories = const [],
  });

  final VoicePhase phase;

  /// What's been heard so far, or the final sentence. While listening,
  /// only the words the recogniser has settled on.
  final String text;

  /// While listening: words still being worked out after [text], which can
  /// still change — shown greyed.
  final String pending;

  /// The readings to choose from, the most likely first.
  final List<ResolvedVoiceDraft> options;

  /// What went wrong, in the error phase.
  final String? message;

  /// What a card's account and category can be changed to.
  final List<Account> accounts;
  final List<Category> categories;

  /// The categories an option of [kind] can take, in the person's order.
  List<Category> categoriesFor(VoiceDraftKind kind) {
    final wanted = switch (kind) {
      VoiceDraftKind.expense => 'expense',
      VoiceDraftKind.income => 'income',
      _ => plannerCategoryKind,
    };
    return [
      for (final c in categories)
        if (c.kind == wanted) c,
    ];
  }

  VoiceEntryState withOption(int index, ResolvedVoiceDraft option) =>
      VoiceEntryState(
        phase: phase,
        text: text,
        options: [
          for (final (i, o) in options.indexed) i == index ? option : o,
        ],
        message: message,
        accounts: accounts,
        categories: categories,
      );
}

/// One voice entry, from the microphone to a saved record.
class VoiceEntryController extends Notifier<VoiceEntryState> {
  /// Account, category names the recogniser and the AI are told about.
  List<String> _hints = const [];

  @override
  VoiceEntryState build() {
    // Read now: providers can't be read from inside onDispose.
    final speech = ref.read(speechCaptureProvider);
    ref.onDispose(speech.cancel);
    return const VoiceEntryState();
  }

  /// The sheet can close while listening or waiting on the server; nothing
  /// is updated after that.
  void _set(VoiceEntryState next) {
    if (ref.mounted) state = next;
  }

  /// Starts listening. Signed-out or a build without sync says so instead.
  Future<void> listen() async {
    if (ref.read(voiceParserProvider) == null) {
      state = const VoiceEntryState(
        phase: VoicePhase.error,
        message: 'Voice entry isn\'t available in this build.',
      );
      return;
    }
    state = const VoiceEntryState(phase: VoicePhase.listening);
    final speech = ref.read(speechCaptureProvider);
    try {
      final setup = await _setup();
      _hints = [...setup.accounts, ...setup.categories];
      if (!ref.mounted) return;
      await speech.start(onText: _heard, hints: _hints);
    } on SpeechCaptureException catch (e) {
      _set(VoiceEntryState(phase: VoicePhase.error, message: e.message));
    } on Object {
      _set(
        const VoiceEntryState(
          phase: VoicePhase.error,
          message: "Couldn't start listening. Try again.",
        ),
      );
    }
  }

  /// Done talking: stop and read what was said.
  Future<void> stopListening() => ref.read(speechCaptureProvider).stop();

  void _heard(String text, String pending, {required bool done}) {
    if (!ref.mounted || state.phase != VoicePhase.listening) return;
    if (!done) {
      state = VoiceEntryState(
        phase: VoicePhase.listening,
        text: text,
        pending: pending,
      );
      return;
    }
    if (text.trim().isEmpty) {
      state = const VoiceEntryState(
        phase: VoicePhase.error,
        message: "Didn't catch that. Tap the mic and try again.",
      );
      return;
    }
    unawaited(understand(text));
  }

  /// Sends [text] to be read; also used to retry the same sentence.
  Future<void> understand(String text) async {
    final parser = ref.read(voiceParserProvider);
    if (parser == null) return;
    final currency = ref.read(settingsProvider).currencyCode;
    final memory = CategoryMemory(ref.read(appDatabaseProvider));
    state = VoiceEntryState(phase: VoicePhase.thinking, text: text);
    try {
      final setup = await _setup();
      final drafts = await parser.parse(
        VoiceRequest(
          text: text,
          now: DateTime.now(),
          timeZone: DateTime.now().timeZoneName,
          currency: currency,
          accounts: setup.accounts,
          expenseCategories: setup.expense,
          incomeCategories: setup.income,
          plannerCategories: setup.planner,
        ),
      );
      final now = DateTime.now();
      final options = await memory.apply(
        [
          for (final d in drafts)
            d.resolve(
              accounts: setup.accountRows,
              categories: setup.categoryRows,
              now: now,
            ),
        ],
        spoken: text,
        categories: setup.categoryRows,
      );
      _set(
        VoiceEntryState(
          phase: VoicePhase.choosing,
          text: text,
          options: options,
          accounts: setup.accountRows,
          categories: setup.categoryRows,
        ),
      );
    } on VoiceParseException catch (e) {
      _set(
        VoiceEntryState(phase: VoicePhase.error, text: text, message: e.message),
      );
    } on Object {
      _set(
        VoiceEntryState(
          phase: VoicePhase.error,
          text: text,
          message: "Couldn't understand that just now. Try again.",
        ),
      );
    }
  }

  /// A detail changed on a card (category, account, date) before saving.
  void edit(int index, ResolvedVoiceDraft option) {
    if (state.phase != VoicePhase.choosing) return;
    state = state.withOption(index, option);
  }

  /// Saves [option]; returns how to take it back.
  Future<SavedVoiceRecord> choose(ResolvedVoiceDraft option) =>
      ref.read(voiceDraftSaverProvider).save(option);

  Future<_Setup> _setup() async {
    // Read up front: nothing from `ref` after an await.
    final finance = ref.read(financeRepositoryProvider);
    final tasks = ref.read(tasksRepositoryProvider);
    final accounts = [
      for (final a in await finance.watchAccounts().first)
        if (a.isActive && normalizeAccountTypeKey(a.type) != 'investment') a,
    ];
    final finCategories = await finance.watchCategories().first;
    final planner = await tasks.watchCategories().first;
    return _Setup(
      accountRows: accounts,
      categoryRows: [...finCategories, ...planner],
    );
  }
}

class _Setup {
  _Setup({required this.accountRows, required this.categoryRows});

  final List<Account> accountRows;
  final List<Category> categoryRows;

  List<String> get accounts => [for (final a in accountRows) a.name];
  List<String> _of(String kind) => [
    for (final c in categoryRows)
      if (c.kind == kind) c.name,
  ];
  List<String> get expense => _of('expense');
  List<String> get income => _of('income');
  List<String> get planner => _of(plannerCategoryKind);
  List<String> get categories => [for (final c in categoryRows) c.name];
}

final voiceEntryControllerProvider =
    NotifierProvider.autoDispose<VoiceEntryController, VoiceEntryState>(
      VoiceEntryController.new,
    );
