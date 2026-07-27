import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('finance: account -> transaction -> budget CRUD and balance sum', () async {
    final category = await db
        .into(db.categories)
        .insertReturning(CategoriesCompanion.insert(
          name: 'Dining',
          colorHex: '#E0475A',
        ));

    final account = await db
        .into(db.accounts)
        .insertReturning(AccountsCompanion.insert(
          name: 'Checking',
          type: 'checking',
          balanceMinor: const Value(8234000),
        ));

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          accountId: account.id,
          categoryId: Value(category.id),
          merchant: 'Swiggy',
          amountMinor: -64000,
          date: DateTime(2026, 7, 26),
        ));

    final txns = await db.select(db.transactions).get();
    expect(txns, hasLength(1));
    expect(txns.first.merchant, 'Swiggy');

    await db.into(db.budgets).insert(BudgetsCompanion.insert(
          categoryId: category.id,
          limitMinor: 600000,
          startDate: DateTime(2026, 7, 1),
        ));
    final budgets = await db.select(db.budgets).get();
    expect(budgets, hasLength(1));
  });

  test('habits: log completion and read back this week', () async {
    final habit = await db
        .into(db.habits)
        .insertReturning(HabitsCompanion.insert(name: 'Morning workout'));

    await db.into(db.habitLogs).insert(HabitLogsCompanion.insert(
          habitId: habit.id,
          date: DateTime(2026, 7, 26),
        ));

    final logs = await (db.select(db.habitLogs)
          ..where((t) => t.habitId.equals(habit.id)))
        .get();
    expect(logs, hasLength(1));
    expect(logs.first.completed, isTrue);
  });

  test('tasks: create and mark done', () async {
    final task = await db.into(db.tasks).insertReturning(
          TasksCompanion.insert(title: 'Finish Q3 budget review'),
        );

    await (db.update(db.tasks)..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        status: const Value('done'),
        completedAt: Value(DateTime(2026, 7, 26)),
      ),
    );

    final updated = await (db.select(db.tasks)
          ..where((t) => t.id.equals(task.id)))
        .getSingle();
    expect(updated.status, 'done');
  });

  test('goals: link a goal to an account via GoalLinks', () async {
    final account = await db
        .into(db.accounts)
        .insertReturning(AccountsCompanion.insert(name: 'Savings', type: 'savings'));
    final goal = await db.into(db.goals).insertReturning(
          GoalsCompanion.insert(title: 'Emergency Fund', type: const Value('financial')),
        );

    await db.into(db.goalLinks).insert(GoalLinksCompanion.insert(
          goalId: goal.id,
          linkedType: 'account',
          linkedId: account.id,
        ));

    final links = await (db.select(db.goalLinks)
          ..where((t) => t.goalId.equals(goal.id)))
        .get();
    expect(links, hasLength(1));
    expect(links.first.linkedId, account.id);
  });

  test('calendar: event with polymorphic source reference', () async {
    final task = await db
        .into(db.tasks)
        .insertReturning(TasksCompanion.insert(title: 'Call plumber'));

    await db.into(db.events).insert(EventsCompanion.insert(
          title: 'Call plumber',
          startTime: DateTime(2026, 7, 26, 11),
          sourceType: const Value('task'),
          sourceId: Value(task.id),
        ));

    final events = await db.select(db.events).get();
    expect(events, hasLength(1));
    expect(events.first.sourceType, 'task');
  });

  test('notes and documents share the Folders table by scope', () async {
    final notesFolder = await db
        .into(db.folders)
        .insertReturning(FoldersCompanion.insert(name: 'Work', scope: 'notes'));
    final docsFolder = await db
        .into(db.folders)
        .insertReturning(FoldersCompanion.insert(name: 'Receipts', scope: 'documents'));

    await db.into(db.notes).insert(NotesCompanion.insert(
          title: 'Q3 planning notes',
          folderId: Value(notesFolder.id),
        ));
    await db.into(db.documents).insert(DocumentsCompanion.insert(
          title: 'Rent_receipt_July.pdf',
          filePath: 'documents/rent_receipt_july.pdf',
          mimeType: 'application/pdf',
          folderId: Value(docsFolder.id),
        ));

    final notes = await db.select(db.notes).get();
    final docs = await db.select(db.documents).get();
    expect(notes, hasLength(1));
    expect(docs, hasLength(1));
  });

  test('insights: dismiss an insight', () async {
    final insight = await db.into(db.insights).insertReturning(
          InsightsCompanion.insert(
            type: 'overspend',
            severity: 'warning',
            title: "You're 18% over your Dining budget this week",
          ),
        );

    await (db.update(db.insights)..where((t) => t.id.equals(insight.id)))
        .write(const InsightsCompanion(dismissed: Value(true)));

    final updated = await (db.select(db.insights)
          ..where((t) => t.id.equals(insight.id)))
        .getSingle();
    expect(updated.dismissed, isTrue);
  });

  test('app settings: singleton row upsert', () async {
    await db.into(db.appSettings).insertOnConflictUpdate(
          const AppSettingsCompanion(
            id: Value(0),
            themeMode: Value('dark'),
          ),
        );

    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.themeMode, 'dark');
  });
}
