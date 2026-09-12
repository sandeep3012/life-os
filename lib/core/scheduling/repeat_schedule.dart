import 'dart:convert';

/// Fixed local-calendar schedule. Month/year repeats clamp to the last day
/// of shorter months without changing the anchor (Jan 31 -> Feb 28 -> Mar 31).
class RepeatSchedule {
  const RepeatSchedule({required this.start, this.frequency = 'none',
    this.weekdays = const [], this.end, this.previous, this.effectiveFrom});
  final DateTime start;
  final String frequency;
  final List<int> weekdays;
  final DateTime? end;
  final RepeatSchedule? previous;
  final DateTime? effectiveFrom;
  DateTime get trackingStart => previous?.trackingStart ?? start;
  bool get hasOccurrence => between(start, DateTime(start.year + 1, start.month, start.day)).isNotEmpty;
  static const frequencies = ['none', 'daily', 'weekly', 'monthly', 'yearly'];
  static DateTime day(DateTime date) => DateTime(date.year, date.month, date.day);

  bool includes(DateTime date) {
    final d = day(date);
    if (previous != null && effectiveFrom != null && d.isBefore(day(effectiveFrom!))) return previous!.includes(d);
    if (d.isBefore(day(start)) || (end != null && d.isAfter(day(end!)))) return false;
    switch (frequency) {
      case 'none': return d == day(start);
      case 'daily': return true;
      case 'weekly': return (weekdays.isEmpty ? [start.weekday] : weekdays).contains(d.weekday);
      case 'monthly': return d.day == _clampedDay(d.year, d.month);
      case 'yearly': return d.month == start.month && d.day == _clampedDay(d.year, d.month);
      default: return false;
    }
  }

  int _clampedDay(int year, int month) {
    final last = DateTime(year, month + 1, 0).day;
    return start.day > last ? last : start.day;
  }

  Iterable<DateTime> between(DateTime from, DateTime through) sync* {
    var cursor = day(from.isBefore(trackingStart) ? trackingStart : from);
    final limit = day(end != null && end!.isBefore(through) ? end! : through);
    while (!cursor.isAfter(limit)) {
      if (includes(cursor)) {
        yield DateTime(cursor.year, cursor.month, cursor.day, start.hour, start.minute);
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
  }

  RepeatSchedule copyWith({DateTime? start, String? frequency, List<int>? weekdays,
    DateTime? end, bool clearEnd = false}) => RepeatSchedule(
      start: start ?? this.start, frequency: frequency ?? this.frequency,
      weekdays: weekdays ?? this.weekdays, end: clearEnd ? null : end ?? this.end,
      previous: previous, effectiveFrom: effectiveFrom);
  String encode() => jsonEncode({'start': start.toIso8601String(),
    'frequency': frequency, 'weekdays': weekdays, 'end': end?.toIso8601String(),
    'previous': previous?.encode(), 'effectiveFrom': effectiveFrom?.toIso8601String()});

  static RepeatSchedule? decode(String? value) {
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    final frequency = json['frequency'] as String;
    if (!frequencies.contains(frequency)) throw FormatException('Invalid repeat frequency');
    final weekdays = (json['weekdays'] as List).cast<int>();
    if (weekdays.any((d) => d < 1 || d > 7)) throw FormatException('Invalid weekdays');
    final result = RepeatSchedule(start: DateTime.parse(json['start'] as String),
      frequency: frequency, weekdays: weekdays,
      end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
      previous: decode(json['previous'] as String?),
      effectiveFrom: json['effectiveFrom'] == null ? null : DateTime.parse(json['effectiveFrom'] as String));
    if (result.end != null && day(result.end!).isBefore(day(result.start))) {
      throw FormatException('Repeat end precedes start');
    }
    return result;
  }
}
