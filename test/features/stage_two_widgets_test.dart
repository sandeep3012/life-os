import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/database/app_database.dart';
import 'package:life_manager/app/theme/app_theme.dart';
import 'package:life_manager/core/database/app_database_provider.dart';
import 'package:life_manager/core/reminders/reminder_status.dart';
import 'package:life_manager/core/services/notification_service.dart';
import 'package:life_manager/features/finance/presentation/screens/reports_screen.dart';
import 'package:life_manager/features/goals/data/goals_repository.dart';
import 'package:life_manager/features/goals/presentation/screens/goal_detail_screen.dart';
import 'package:life_manager/features/settings/presentation/widgets/reminder_status_card.dart';

class _Notifications extends NotificationService {
  int requests = 0;
  @override
  Future<ReminderStatus> readStatus() async => ReminderStatus(
    enabled: requests > 0,
    exactAlarms: false,
    pendingCount: 2,
    scheduled: [QueuedReminder('Read', DateTime(2027, 1, 1, 9))],
  );
  @override
  Future<void> requestReminderPermissions() async {
    requests++;
  }
}

void main() {
  testWidgets(
    'reminder status shows queue and requests permission only on tap',
    (tester) async {
      final service = _Notifications();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [notificationServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ReminderStatusCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Permission: Disabled'), findsOneWidget);
      expect(find.text('2 pending notifications'), findsOneWidget);
      expect(service.requests, 0);
      await tester.tap(find.text('Request permission'));
      await tester.pumpAndSettle();
      expect(find.text('Permission: Enabled'), findsOneWidget);
      expect(service.requests, 1);
    },
  );

  testWidgets('report filters and custom date selector are available', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(AccountsCompanion.insert(name: 'Wallet', type: 'cash'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All accounts').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallet').last);
    await tester.pumpAndSettle();
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.textContaining('Compared with'), findsOneWidget);
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'automatic task goal replaces manual controls and restores manual value',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = GoalsRepository(db);
      final goalId = await repo.createGoal(
        title: 'Finish tasks',
        targetValue: 10,
        currentValue: 4,
      );
      final task = await db
          .into(db.tasks)
          .insertReturning(
            TasksCompanion.insert(
              title: 'Done task',
              status: const Value('done'),
            ),
          );
      await repo.addLink(goalId: goalId, linkedType: 'task', linkedId: task.id);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: GoalDetailScreen(goalId: goalId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4 / 10'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('1 / 10'), findsOneWidget);
      expect(find.byIcon(LucideIcons.minus), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(find.text('4 / 10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
