import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/utils/date_utils.dart';
import '../../application/calendar_providers.dart';
import '../../domain/calendar_item.dart';
import '../widgets/calendar_item_tile.dart';
import '../widgets/quick_add_event_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final selectedDay = ref.watch(selectedCalendarDayProvider);
    final markersByDay = ref.watch(calendarMarkersByDayProvider);
    final dayItems = ref.watch(selectedDayItemsProvider);

    return Scaffold(
      drawer: const AppSidebar(),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Calendar',
                  centerIsTitle: true,
                  showTrailing: false,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
        children: [
          TableCalendar<CalendarItemType>(
            focusedDay: _focusedMonth,
            firstDay: DateTime(2020),
            lastDay: DateTime(2035),
            currentDay: dateOnly(DateTime.now()),
            selectedDayPredicate: (day) => dateOnly(day) == selectedDay,
            eventLoader: (day) => (markersByDay[dateOnly(day)] ?? const {}).toList(),
            onDaySelected: (selected, focused) {
              ref.read(selectedCalendarDayProvider.notifier).select(selected);
              setState(() => _focusedMonth = focused);
            },
            onPageChanged: (focused) => setState(() => _focusedMonth = focused),
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final type in events.take(3))
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: colorForCalendarItemType(context, type),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            // A Row can't shrink below its children's intrinsic width, and the
            // date plus three legend labels don't fit a phone — this overflowed
            // by ~98px at 392pt. Wrap spreads them when there's room and drops
            // the legend to a second line when there isn't.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: [
                Text(DateFormat.yMMMEd().format(selectedDay), style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _LegendDot(label: 'Task', color: colors.tasks),
                    _LegendDot(label: 'Habit', color: colors.habits),
                    _LegendDot(label: 'Event', color: colors.calendar),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: dayItems.isEmpty
                ? Center(
                    child: Text(
                      'Nothing scheduled for this day.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: dayItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _buildItemTile(context, dayItems[index]),
                  ),
          ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showQuickAddEventSheet(context, initialDate: selectedDay);
          if (result == null) return;
          await ref
              .read(calendarControllerProvider)
              .addEvent(
                title: result.title,
                startTime: result.startTime,
                endTime: result.endTime,
                frequency: result.frequency,
                recurrenceEndDate: result.recurrenceEndDate,
                reminderEnabled: result.reminderEnabled,
                reminderMode: result.reminderMode,
                reminderMinutesBefore: result.reminderMinutesBefore,
              );
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('New event'),
      ),
    );
  }

  /// Manual events (not tasks/habits/bills, which keep navigating to their
  /// own modules elsewhere) get tap-to-edit and swipe-to-delete.
  Widget _buildItemTile(BuildContext context, CalendarItem item) {
    if (item.type != CalendarItemType.event || item.sourceId == null) {
      return CalendarItemTile(item: item);
    }
    final eventId = item.sourceId!;
    final recurrenceId = item.recurrenceId;
    return Dismissible(
      key: ValueKey(eventId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(LucideIcons.trash2, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final choice = await _confirmDelete(context, isPartOfSeries: recurrenceId != null);
        switch (choice) {
          case _DeleteChoice.cancel:
            return false;
          case _DeleteChoice.thisEvent:
            await ref.read(calendarControllerProvider).deleteEvent(eventId);
            return true;
          case _DeleteChoice.allInSeries:
            await ref.read(calendarControllerProvider).deleteEventSeries(recurrenceId!);
            return true;
        }
      },
      child: CalendarItemTile(item: item, onTap: () => _editEvent(context, eventId)),
    );
  }

  /// Offers "delete this event" alone for a standalone event, or a third
  /// "delete all events in this series" option when the event belongs to a
  /// recurring series (see the calendar delete-series plan notes).
  Future<_DeleteChoice> _confirmDelete(BuildContext context, {required bool isPartOfSeries}) async {
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          isPartOfSeries
              ? 'This event repeats. Choose what to delete.'
              : 'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.cancel),
            child: const Text('Cancel'),
          ),
          if (isPartOfSeries)
            TextButton(
              onPressed: () => Navigator.of(context).pop(_DeleteChoice.allInSeries),
              child: Text(
                'Delete all events',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteChoice.thisEvent),
            child: Text(
              isPartOfSeries ? 'Delete this event' : 'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    return choice ?? _DeleteChoice.cancel;
  }

  Future<void> _editEvent(BuildContext context, String eventId) async {
    final event = await ref.read(calendarRepositoryProvider).getEvent(eventId);
    if (event == null || !context.mounted) return;
    final result = await showQuickAddEventSheet(
      context,
      initialDate: dateOnly(event.startTime),
      initial: event,
      onDelete: () async {
        final choice = await _confirmDelete(context, isPartOfSeries: event.recurrenceId != null);
        switch (choice) {
          case _DeleteChoice.cancel:
            return;
          case _DeleteChoice.thisEvent:
            await ref.read(calendarControllerProvider).deleteEvent(eventId);
          case _DeleteChoice.allInSeries:
            await ref.read(calendarControllerProvider).deleteEventSeries(event.recurrenceId!);
        }
      },
    );
    if (result == null) return;
    await ref
        .read(calendarControllerProvider)
        .updateEvent(
          id: eventId,
          title: result.title,
          startTime: result.startTime,
          endTime: result.endTime,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
          reminderMinutesBefore: result.reminderMinutesBefore,
        );
  }
}

enum _DeleteChoice { cancel, thisEvent, allInSeries }

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
