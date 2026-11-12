import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/voice_entry/domain/voice_draft.dart';

Account _account(String id, String name) => Account(
  id: id,
  name: name,
  type: 'savings',
  balanceMinor: 0,
  openingBalanceMinor: 0,
  currencyCode: 'INR',
  isActive: true,
  position: 0,
  isDefault: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Category _category(String id, String name, String kind) => Category(
  id: id,
  name: name,
  icon: 'label',
  colorHex: '#000000',
  kind: kind,
  position: 0,
  createdAt: DateTime(2026),
);

void main() {
  final accounts = [_account('cash', 'Cash Wallet'), _account('hdfc', 'HDFC Savings')];
  final categories = [
    _category('food', 'Dining', 'expense'),
    _category('rent', 'Rent', 'expense'),
    _category('pay', 'Salary', 'income'),
    _category('fit', 'Fitness', plannerCategoryKind),
  ];
  final now = DateTime(2026, 11, 5, 14, 30);

  test('reads an option and matches it to this phone\'s accounts', () {
    final draft = VoiceDraft.fromJson({
      'kind': 'expense',
      'summary': '₹250 · Dining · HDFC',
      'title': 'Lunch at Subway',
      'amount': 250.5,
      'account': 'HDFC', // partial name
      'category': 'dining', // any case
      'date': '2026-11-05',
      'time': null,
      'endTime': null,
      'repeat': 'none',
      'weekdays': <int>[],
      'notes': null,
    })!;
    final r = draft.resolve(accounts: accounts, categories: categories, now: now);
    expect(r.account!.id, 'hdfc');
    expect(r.category!.id, 'food');
    expect(r.amountMinor, -25050);
    expect(r.when, DateTime(2026, 11, 5));
    expect(r.hasTime, isFalse);
    expect(r.canSave, isTrue);
  });

  test('unknown names fall back sensibly', () {
    final money = VoiceDraft.fromJson({
      'kind': 'income',
      'title': 'Refund',
      'amount': 100,
      'account': 'Some bank I never added',
      'category': 'Nope',
    })!;
    final m = money.resolve(accounts: accounts, categories: categories, now: now);
    expect(m.account!.id, 'cash', reason: 'the top account');
    expect(m.category!.id, 'pay', reason: 'money always gets a category');
    expect(m.amountMinor, 10000);

    final task = VoiceDraft.fromJson({
      'kind': 'task',
      'title': 'Call Mom',
      'category': 'Nope',
      'date': '2026-11-06',
      'time': '18:00',
    })!;
    final t = task.resolve(accounts: accounts, categories: categories, now: now);
    expect(t.category, isNull, reason: 'tasks stay uncategorised');
    expect(t.when, DateTime(2026, 11, 6, 18));
    expect(t.hasTime, isTrue);
  });

  test('events get an end time only when it comes after the start', () {
    VoiceDraft event(String end) => VoiceDraft.fromJson({
      'kind': 'event',
      'title': 'Meeting with Raj',
      'date': '2026-11-07',
      'time': '15:00',
      'endTime': end,
    })!;
    expect(
      event('16:00').resolve(accounts: accounts, categories: categories, now: now).endsAt,
      DateTime(2026, 11, 7, 16),
    );
    expect(
      event('14:00').resolve(accounts: accounts, categories: categories, now: now).endsAt,
      isNull,
    );
  });

  test('a weekly habit keeps its days', () {
    final habit = VoiceDraft.fromJson({
      'kind': 'habit',
      'title': 'Gym',
      'category': 'Fitness',
      'time': '07:00',
      'repeat': 'weekly',
      'weekdays': [1, 3, 5, 9],
    })!;
    final r = habit.resolve(accounts: accounts, categories: categories, now: now);
    expect(r.category!.id, 'fit');
    expect(r.schedule(r.when!).weekdays, [1, 3, 5]);
    expect(r.when, DateTime(2026, 11, 5, 7), reason: 'no date means today');
  });

  test('unusable options are dropped', () {
    expect(VoiceDraft.fromJson({'kind': 'expense', 'title': 'Lunch'}), isNull,
        reason: 'money without an amount');
    expect(VoiceDraft.fromJson({'kind': 'party', 'title': 'x'}), isNull);
    expect(VoiceDraft.fromJson({'kind': 'task', 'title': '  '}), isNull);
    expect(VoiceDraft.fromJson('nonsense'), isNull);
  });

  test('money cannot be saved without an account', () {
    final r = VoiceDraft.fromJson({'kind': 'expense', 'title': 'Tea', 'amount': 20})!
        .resolve(accounts: const [], categories: categories, now: now);
    expect(r.canSave, isFalse);
  });
}
