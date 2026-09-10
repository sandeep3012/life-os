import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'repeat_schedule.dart';

/// Shared controlled fields for task, habit and event schedules.
class ScheduleFields extends StatelessWidget {
  const ScheduleFields({super.key, required this.value, required this.onChanged,
    this.showStart = true, this.allowRepeatChanges = true, this.firstDate});
  final DateTime? firstDate;
  final RepeatSchedule value;
  final ValueChanged<RepeatSchedule> onChanged;
  final bool showStart;
  final bool allowRepeatChanges;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showStart) Wrap(spacing: 8, children: [
        TextButton.icon(icon: const Icon(Icons.calendar_today_rounded),
          label: Text(DateFormat.yMMMd().format(value.start)), onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: value.start,
              firstDate: firstDate ?? DateTime(2000), lastDate: DateTime(2100));
            if (date == null || !context.mounted) return;
            final start = DateTime(date.year, date.month, date.day, value.start.hour, value.start.minute);
            onChanged(value.copyWith(start: start,
              clearEnd: value.end != null && RepeatSchedule.day(value.end!).isBefore(date)));
          }),
        TextButton.icon(icon: const Icon(Icons.schedule_rounded),
          label: Text(TimeOfDay.fromDateTime(value.start).format(context)), onPressed: () async {
            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value.start));
            if (time == null || !context.mounted) return;
            onChanged(value.copyWith(start: DateTime(value.start.year, value.start.month, value.start.day, time.hour, time.minute)));
          }),
      ]),
      if (allowRepeatChanges) ...[
        const Text('Repeat'),
        Wrap(spacing: 8, children: [
          for (final f in RepeatSchedule.frequencies)
            ChoiceChip(label: Text(f == 'none' ? 'Does not repeat' : '${f[0].toUpperCase()}${f.substring(1)}'),
              selected: value.frequency == f,
              onSelected: (_) => onChanged(value.copyWith(frequency: f))),
        ]),
        if (value.frequency == 'weekly') Wrap(spacing: 4, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(label: Text((const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])[d - 1]),
              selected: (value.weekdays.isEmpty ? [value.start.weekday] : value.weekdays).contains(d),
              onSelected: (selected) {
                final days = {...(value.weekdays.isEmpty ? [value.start.weekday] : value.weekdays)};
                selected ? days.add(d) : days.remove(d);
                if (days.isNotEmpty) onChanged(value.copyWith(weekdays: days.toList()..sort()));
              }),
        ]),
        if (value.frequency != 'none') Row(children: [
          Expanded(child: TextButton.icon(icon: const Icon(Icons.event_busy_rounded),
            label: Text(value.end == null ? 'Ends: never' : 'Ends: ${DateFormat.yMMMd().format(value.end!)}'),
            onPressed: () async {
              final date = await showDatePicker(context: context,
                initialDate: value.end ?? value.start, firstDate: RepeatSchedule.day(value.start), lastDate: DateTime(2100));
              if (date != null && context.mounted) onChanged(value.copyWith(end: date));
            })),
          if (value.end != null) IconButton(tooltip: 'Clear repeat end', icon: const Icon(Icons.close),
            onPressed: () => onChanged(value.copyWith(clearEnd: true))),
        ]),
      ],
    ]);
  }
}
