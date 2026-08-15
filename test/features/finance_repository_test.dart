import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/core/services/file_storage_service.dart';
import 'package:life_manager/features/finance/data/finance_repository.dart';

void main() {
  late AppDatabase db;
  late FinanceRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FinanceRepository(db, FileStorageService());
  });

  tearDown(() => db.close());

  test('watchCategories excludes non-finance kinds like habit', () async {
    await repo.createCategory(name: 'Groceries', icon: 'shopping_cart', colorHex: '#2E9E63');
    await repo.createCategory(
      name: 'Salary',
      icon: 'payments',
      colorHex: '#1E8F5E',
      kind: 'income',
    );
    // Not created through FinanceRepository — simulates a habit category
    // row existing in the same shared Categories table.
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: 'Fitness',
            colorHex: '#2E9E63',
            kind: const Value('habit'),
          ),
        );

    final categories = await repo.watchCategories().first;
    expect(categories, hasLength(2));
    expect(categories.map((c) => c.kind), everyElement(isIn(['expense', 'income'])));
    expect(categories.map((c) => c.name), isNot(contains('Fitness')));
  });
}
