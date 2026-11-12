import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/reminders/reminder_mode.dart';
import '../../calendar/application/calendar_providers.dart';
import '../../finance/domain/payment_mode.dart';
import '../../finance/application/finance_providers.dart';
import '../../habits/application/habits_providers.dart';
import '../../tasks/application/tasks_providers.dart';
import '../domain/voice_draft.dart';

/// What was saved, and how to take it back.
class SavedVoiceRecord {
  const SavedVoiceRecord({required this.message, required this.undo});

  /// "Expense added", "Task added"…
  final String message;
  final Future<void> Function() undo;
}

/// Saves a chosen voice option through the same controllers the add forms
/// use, so balances, reminders and sync behave exactly as for a typed entry.
class VoiceDraftSaver {
  VoiceDraftSaver(this._ref);

  final Ref _ref;

  Future<SavedVoiceRecord> save(ResolvedVoiceDraft d) async {
    final draft = d.draft;
    final now = DateTime.now();
    final repeats = draft.repeat != 'none';
    switch (d.kind) {
      case VoiceDraftKind.expense || VoiceDraftKind.income:
        final finance = _ref.read(financeControllerProvider);
        final id = await finance.addTransaction(
          accountId: d.account!.id,
          categoryId: d.category?.id,
          merchant: draft.title,
          amountMinor: d.amountMinor!,
          date: d.when ?? now,
          note: draft.notes,
          // Speech doesn't say how it was paid; the account is a good guess
          // (a credit card pays by card, a cash account in cash).
          paymentMode: suggestedPaymentModeFor(d.account!.type),
        );
        return SavedVoiceRecord(
          message: d.kind == VoiceDraftKind.expense
              ? 'Expense added'
              : 'Income added',
          undo: () => finance.deleteTransaction(id),
        );

      case VoiceDraftKind.task:
        final tasks = _ref.read(tasksControllerProvider);
        final id = await tasks.addTask(
          title: draft.title,
          description: draft.notes,
          categoryId: d.category?.id,
          dueDate: d.when,
          schedule: d.when != null && repeats ? d.schedule(d.when!) : null,
          // A time was said, so a reminder at it is what's meant.
          reminderEnabled: d.hasTime,
          reminderMode: ReminderMode.notification,
        );
        return SavedVoiceRecord(
          message: repeats ? 'Repeating task added' : 'Task added',
          undo: () async {
            final db = _ref.read(appDatabaseProvider);
            final task = await (db.select(
              db.tasks,
            )..where((t) => t.id.equals(id))).getSingleOrNull();
            if (task == null) return;
            // A repeating task's whole series goes, from its first one on.
            await tasks.deleteTask(task, following: task.recurrenceId != null);
          },
        );

      case VoiceDraftKind.habit:
        final habits = _ref.read(habitsControllerProvider);
        final id = await habits.addHabit(
          draft.title,
          categoryId: d.category?.id,
          description: draft.notes,
          // A habit always repeats; daily unless a pattern was said.
          schedule: repeats ? d.schedule(d.when ?? now) : null,
          reminderEnabled: d.hasTime,
          reminderHour: d.hasTime ? d.when!.hour : null,
          reminderMinute: d.hasTime ? d.when!.minute : null,
        );
        return SavedVoiceRecord(
          message: 'Habit added',
          undo: () => habits.deleteNewHabit(id),
        );

      case VoiceDraftKind.event:
        final calendar = _ref.read(calendarControllerProvider);
        final start = d.when ?? DateTime(now.year, now.month, now.day, 9);
        final event = await calendar.addEvent(
          title: draft.title,
          description: draft.notes,
          schedule: repeats ? d.schedule(start) : null,
          startTime: start,
          endTime: d.endsAt ?? start.add(const Duration(hours: 1)),
          frequency: draft.repeat,
        );
        return SavedVoiceRecord(
          message: repeats ? 'Repeating event added' : 'Event added',
          undo: () async {
            final series = event.recurrenceId;
            if (series != null) {
              await calendar.deleteEventSeries(series);
            } else {
              await calendar.deleteEvent(event.id);
            }
          },
        );
    }
  }
}

final voiceDraftSaverProvider = Provider<VoiceDraftSaver>(
  VoiceDraftSaver.new,
);
