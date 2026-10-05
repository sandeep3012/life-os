import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/reminders/reminder_text.dart';

/// What each notification's second line says. Times are matched loosely:
/// intl may put a narrow no-break space before AM/PM.
void main() {
  test('task: due now, priority only when high', () {
    expect(ReminderText.task(priority: 'medium'), 'Due now');
    expect(ReminderText.task(priority: 'high'), 'Due now · High priority');
  });

  test('event: start time and lead, or starting now', () {
    final start = DateTime(2026, 10, 5, 16);
    final body = ReminderText.event(start: start, minutesBefore: 15);
    expect(body, startsWith('Starts at 4:00'));
    expect(body, endsWith('PM, in 15 min'));
    expect(
      ReminderText.event(start: start, minutesBefore: 90),
      endsWith('in 1 hour 30 min'),
    );
    expect(ReminderText.event(start: start, minutesBefore: 0), 'Starting now');
  });

  test('habit: the day\'s target when there is one', () {
    expect(ReminderText.habit(), 'Time to check in');
    expect(
      ReminderText.habit(targetAmount: 8, targetUnit: 'glasses'),
      'Time to check in · 8 glasses today',
    );
    expect(
      ReminderText.habit(targetAmount: 2.5, targetUnit: 'km'),
      'Time to check in · 2.5 km today',
    );
  });

  test('medication: which dose, plus the dosage note', () {
    final plain = ReminderText.medication(hour: 8, minute: 0);
    expect(plain, startsWith('8:00'));
    expect(plain, endsWith('AM dose'));
    expect(
      ReminderText.medication(
        hour: 8,
        minute: 0,
        dosageNote: '1 tablet after food',
      ),
      endsWith('AM dose · 1 tablet after food'),
    );
  });

  group('bill and goal count from when the reminder fires', () {
    final due = DateTime(2026, 10, 10, 9);

    test('days early', () {
      expect(
        ReminderText.bill(
          amount: '₹1,250',
          dueDate: due,
          firesAt: DateTime(2026, 10, 7, 9),
        ),
        '₹1,250 due in 3 days (Sat, 10 Oct)',
      );
      expect(
        ReminderText.goal(deadline: due, firesAt: DateTime(2026, 10, 8, 9)),
        'Deadline in 2 days (Sat, 10 Oct)',
      );
    });

    test('the day before', () {
      expect(
        ReminderText.bill(
          amount: '₹1,250',
          dueDate: due,
          firesAt: DateTime(2026, 10, 9, 20),
        ),
        '₹1,250 due tomorrow (Sat, 10 Oct)',
      );
    });

    test('on the day', () {
      expect(
        ReminderText.bill(amount: '₹1,250', dueDate: due, firesAt: due),
        '₹1,250 due today',
      );
      expect(
        ReminderText.goal(deadline: due, firesAt: due),
        'Deadline today',
      );
    });
  });
}
