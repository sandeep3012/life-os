import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/scheduling/repeat_schedule.dart';

void main() {
  test('selected weekdays, start and inclusive end', () {
    final rule = RepeatSchedule(start: DateTime(2026, 9, 7, 9, 30),
      frequency: 'weekly', weekdays: [1, 3, 5], end: DateTime(2026, 9, 11));
    expect(rule.between(DateTime(2026, 9, 1), DateTime(2026, 10)).toList(), [
      DateTime(2026, 9, 7, 9, 30), DateTime(2026, 9, 9, 9, 30), DateTime(2026, 9, 11, 9, 30),
    ]);
    expect(rule.includes(DateTime(2026, 9, 12)), isFalse);
  });
  test('monthly repeats do not drift after a shorter month', () {
    final rule = RepeatSchedule(start: DateTime(2026, 1, 31, 8), frequency: 'monthly');
    expect(rule.between(rule.start, DateTime(2026, 4, 30)).toList(), [
      DateTime(2026, 1, 31, 8), DateTime(2026, 2, 28, 8), DateTime(2026, 3, 31, 8), DateTime(2026, 4, 30, 8),
    ]);
  });
  test('leap-year anniversary returns to February 29', () {
    final rule = RepeatSchedule(start: DateTime(2024, 2, 29), frequency: 'yearly');
    expect(rule.includes(DateTime(2025, 2, 28)), isTrue);
    expect(rule.includes(DateTime(2028, 2, 29)), isTrue);
    expect(rule.includes(DateTime(2028, 2, 28)), isFalse);
  });
  test('no repeat produces one occurrence; empty ranges are detectable', () {
    final rule = RepeatSchedule(start: DateTime(2026, 9, 7));
    expect(rule.between(rule.start, DateTime(2030)).length, 1);
    expect(RepeatSchedule(start: rule.start, frequency: 'weekly', weekdays: [3], end: rule.start).hasOccurrence, isFalse);
  });
  test('encoding preserves schedule and historical revisions', () {
    final old = RepeatSchedule(start: DateTime(2026, 9, 1), frequency: 'daily');
    final rule = RepeatSchedule(start: old.start, frequency: 'weekly', weekdays: [1],
      previous: old, effectiveFrom: DateTime(2026, 9, 9));
    final restored = RepeatSchedule.decode(rule.encode())!;
    expect(restored.includes(DateTime(2026, 9, 8)), isTrue);
    expect(restored.includes(DateTime(2026, 9, 10)), isFalse);
    expect(restored.includes(DateTime(2026, 9, 14)), isTrue);
    expect(RepeatSchedule.decode(null), isNull);
  });
  test('invalid repeat ranges and weekdays are rejected', () {
    expect(() => RepeatSchedule.decode(RepeatSchedule(start: DateTime(2026), end: DateTime(2025)).encode()), throwsFormatException);
    expect(() => RepeatSchedule.decode(RepeatSchedule(start: DateTime(2026), weekdays: [8]).encode()), throwsFormatException);
  });
}
