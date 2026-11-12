import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/features/voice_entry/application/category_memory.dart';
import 'package:life_manager/features/voice_entry/domain/voice_draft.dart';

void main() {
  late AppDatabase db;
  late List<Category> categories;
  late Account hdfc;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final (id, name, kind) in [
      ('dining', 'Dining', 'expense'),
      ('delivery', 'Food delivery', 'expense'),
      ('fitness', 'Fitness', plannerCategoryKind),
    ]) {
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: Value(id),
          name: name,
          colorHex: '#000000',
          kind: Value(kind),
        ),
      );
    }
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(id: const Value('hdfc'), name: 'HDFC', type: 'savings'),
    );
    categories = await db.select(db.categories).get();
    hdfc = await db.select(db.accounts).getSingle();
    // Last time, Swiggy went under Food delivery.
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        accountId: 'hdfc',
        categoryId: const Value('delivery'),
        merchant: 'Swiggy',
        amountMinor: -45000,
        date: DateTime(2026, 10, 1),
      ),
    );
    await db.into(db.tasks).insert(
      TasksCompanion.insert(title: 'Gym', categoryId: const Value('fitness')),
    );
  });
  tearDown(() => db.close());

  ResolvedVoiceDraft option(Map<String, Object?> json) => VoiceDraft.fromJson(json)!
      .resolve(accounts: [hdfc], categories: categories, now: DateTime(2026, 11, 6));

  test('a name used before brings back its category', () async {
    final guessed = option({
      'kind': 'expense',
      'title': 'Dinner from Swiggy',
      'amount': 600,
      'category': 'Dining', // the AI's guess
    });
    final [result] = await CategoryMemory(db).apply(
      [guessed],
      spoken: '600 dinner from swiggy',
      categories: categories,
    );
    expect(result.category!.id, 'delivery');
    expect(result.categoryFromHistory, isTrue);
  });

  test('a category said out loud is kept', () async {
    final said = option({
      'kind': 'expense',
      'title': 'Swiggy',
      'amount': 600,
      'category': 'Dining',
    });
    final [result] = await CategoryMemory(db).apply(
      [said],
      spoken: '600 swiggy category dining',
      categories: categories,
    );
    expect(result.category!.id, 'dining');
    expect(result.categoryFromHistory, isFalse);
  });

  test('tasks remember too; unrelated names are left alone', () async {
    final results = await CategoryMemory(db).apply(
      [
        option({'kind': 'task', 'title': 'Gym'}),
        option({'kind': 'task', 'title': 'Buy a lamp'}),
      ],
      spoken: 'gym',
      categories: categories,
    );
    expect(results[0].category!.id, 'fitness');
    expect(results[1].category, isNull);
  });

  test('changing the category by hand drops "as last time"', () {
    final remembered = option({'kind': 'task', 'title': 'Gym'})
        .copyWith(category: categories.first, categoryFromHistory: true);
    expect(remembered.categoryFromHistory, isTrue);
    final changed = remembered.copyWith(category: categories.last);
    expect(changed.categoryFromHistory, isFalse);
    expect(remembered.copyWith(clearCategory: true).category, isNull);
  });
}
