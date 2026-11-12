import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/voice_entry/data/sample_voice_parser.dart';
import 'package:life_manager/features/voice_entry/data/voice_parser.dart';
import 'package:life_manager/features/voice_entry/domain/voice_draft.dart';

VoiceRequest _said(String text) => VoiceRequest(
  text: text,
  now: DateTime(2026, 11, 5, 14),
  timeZone: 'IST',
  currency: 'INR',
  accounts: const ['Cash Wallet', 'HDFC Savings'],
  expenseCategories: const ['Groceries', 'Dining', 'Transport'],
  incomeCategories: const ['Salary'],
  plannerCategories: const ['Fitness', 'Work'],
);

void main() {
  const parser = SampleVoiceParser();

  test('builds three samples from the words heard', () async {
    final options = await parser.parse(
      _said('call mom tomorrow at 6 pm and spend 250'),
    );
    expect(options.map((o) => o.kind), [
      VoiceDraftKind.expense,
      VoiceDraftKind.task,
      VoiceDraftKind.event,
    ]);
    expect(options[0].amount, 6, reason: 'the first number it hears');
    expect(options[1].title, 'Call mom tomorrow at 6 pm and spend 250');
    expect(options[1].date, '2026-11-06');
    expect(options[1].time, '18:00');
  });

  test('a routine becomes a habit sample', () async {
    final options = await parser.parse(_said('meditate every morning'));
    expect(options.last.kind, VoiceDraftKind.habit);
    expect(options.first.amount, 100, reason: 'stand-in amount');
  });

  test('test mode is on in debug builds and swaps in the sample parser', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(voiceTestModeProvider), isTrue);
    expect(container.read(voiceParserProvider), isA<SampleVoiceParser>());
  });

  test('samples guess the category and account from the words', () async {
    final dinner = await parser.parse(_said('2000 for dinner from hdfc'));
    expect(dinner.first.category, 'Dining', reason: 'dinner → Dining');
    expect(dinner.first.account, 'HDFC Savings');

    final gym = await parser.parse(_said('gym every monday at 7 am'));
    expect(gym[1].category, 'Fitness');
    expect(gym.last.kind, VoiceDraftKind.habit);

    final said = await parser.parse(_said('300 transport uber'));
    expect(said.first.category, 'Transport');
  });
}
