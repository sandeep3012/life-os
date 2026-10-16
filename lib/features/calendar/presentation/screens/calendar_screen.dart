import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/undo_snack_bar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/utils/date_utils.dart';
import '../../application/calendar_providers.dart';
import '../../application/calendar_view_providers.dart';
import '../../domain/calendar_item.dart';
import '../widgets/calendar_agenda_view.dart';
import '../widgets/calendar_item_tile.dart';
import '../widgets/quick_add_event_sheet.dart';
import '../../../../app/motion.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();

  /// The month grid folds to the selected day's week while the day's list is
  /// scrolled, so a busy day gets the screen instead of a half-height window
  /// under a fixed month. Pulling the list down from its top unfolds it; so
  /// does tapping the month name, for days too short to scroll.
  CalendarFormat _format = CalendarFormat.month;

  void _setFormat(CalendarFormat format) {
    if (_format == format) return;
    setState(() {
      _format = format;
      // Fold to the week the user is looking at, not the month's first week.
      if (format == CalendarFormat.week) {
        _focusedMonth = ref.read(selectedCalendarDayProvider);
      }
    });
  }

  /// Folds when the user scrolls the list up, unfolds when they pull down
  /// past its top. Only user drags count, so a fling settling doesn't toggle
  /// the calendar on its own.
  bool _onListScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      if (n.scrollDelta! > 0 && n.metrics.pixels > 12) {
        _setFormat(CalendarFormat.week);
      } else if (n.metrics.pixels < -24) {
        _setFormat(CalendarFormat.month); // iOS: bounced past the top
      }
    } else if (n is OverscrollNotification &&
        n.dragDetails != null &&
        n.overscroll < 0) {
      _setFormat(CalendarFormat.month); // Android: pulled at the top
    }
    return false;
  }

  Future<void> _showViewOptions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final layout = ref.watch(calendarLayoutProvider);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Calendar layout',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final option in CalendarLayout.values)
                  ListTile(
                    title: Text(
                      option == CalendarLayout.month ? 'Month' : 'Agenda',
                    ),
                    trailing: layout == option
                        ? const Icon(LucideIcons.check)
                        : null,
                    onTap: () {
                      _focusedMonth = ref.read(selectedCalendarDayProvider);
                      ref.read(calendarLayoutProvider.notifier).select(option);
                      Navigator.of(context).pop();
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    ),
  );

  void _acknowledgeEventSave({required bool updated}) {
    showSaveFeedback(
      context,
      ref,
      title: updated ? 'Event updated' : 'Event saved',
      message: updated
          ? 'Your changes are on the calendar.'
          : 'Your event is on the calendar.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final selectedDay = ref.watch(selectedCalendarDayProvider);
    final markersByDay = ref.watch(calendarMarkersByDayProvider);
    final dayItems = ref.watch(selectedDayItemsProvider);
    final layout = ref.watch(calendarLayoutProvider);

    return Scaffold(
      drawer: const AppSidebar(),
      // Any scroll the person makes — the month list, the agenda — folds
      // the button to its icon; scrolling back to the top unfolds it.
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Builder(
                builder: (context) => AppTopBar(
                  centerText: 'Calendar',
                  centerIsTitle: true,
                  trailingIcon: LucideIcons.slidersVertical,
                  trailingLabel: 'Calendar layout',
                  onTrailing: _showViewOptions,
                  onMenu: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          ),
          Expanded(
            child: layout == CalendarLayout.agenda
                ? CalendarAgendaView(
                    items: ref.watch(allCalendarItemsProvider),
                    selectedDay: selectedDay,
                    onDayChanged: (day) => ref
                        .read(selectedCalendarDayProvider.notifier)
                        .select(day),
                    itemBuilder: (context, item) =>
                        _buildItemTile(context, item, agenda: true),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: SurfaceCard(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                          radius: 22,
                          child: TableCalendar<CalendarItemType>(
                            focusedDay: _focusedMonth,
                            calendarFormat: _format,
                            availableCalendarFormats: const {
                              CalendarFormat.month: 'Month',
                              CalendarFormat.week: 'Week',
                            },
                            // A vertical swipe on the grid folds or unfolds it
                            // too, the package's own gesture.
                            onFormatChanged: _setFormat,
                            onHeaderTapped: (_) => _setFormat(
                              _format == CalendarFormat.month
                                  ? CalendarFormat.week
                                  : CalendarFormat.month,
                            ),
                            formatAnimationDuration: AppMotion.of(
                              context,
                              AppMotion.drawer,
                            ),
                            formatAnimationCurve: AppMotion.curveOf(
                              context,
                              AppMotion.emphasized,
                            ),
                            firstDay: _focusedMonth.isBefore(DateTime(2020))
                                ? dateOnly(_focusedMonth)
                                : DateTime(2020),
                            lastDay: _focusedMonth.isAfter(DateTime(2035))
                                ? dateOnly(_focusedMonth)
                                : DateTime(2035),
                            currentDay: dateOnly(DateTime.now()),
                            selectedDayPredicate: (day) =>
                                dateOnly(day) == selectedDay,
                            eventLoader: (day) =>
                                (markersByDay[dateOnly(day)] ?? const {})
                                    .toList(),
                            onDaySelected: (selected, focused) {
                              ref
                                  .read(selectedCalendarDayProvider.notifier)
                                  .select(selected);
                              setState(() => _focusedMonth = focused);
                            },
                            onPageChanged: (focused) =>
                                setState(() => _focusedMonth = focused),
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
                              todayTextStyle: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
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
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colorForCalendarItemType(
                                              context,
                                              type,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat.yMMMEd().format(selectedDay),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                _LegendDot(label: 'Task', color: colors.tasks),
                                _LegendDot(
                                  label: 'Habit',
                                  color: colors.habits,
                                ),
                                _LegendDot(
                                  label: 'Event',
                                  color: colors.calendar,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: _onListScroll,
                          // Always scrollable, so a short or empty day can
                          // still be pulled down to unfold the month.
                          child: dayItems.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    48,
                                    20,
                                    100,
                                  ),
                                  children: [
                                    Center(
                                      child: Text(
                                        'Nothing scheduled for this day.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    100,
                                  ),
                                  itemCount: dayItems.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) =>
                                      _buildItemTile(context, dayItems[index]),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        isExtended: true,
        extendedIconLabelSpacing: _fabExtended ? 8 : 0,
        extendedPadding: EdgeInsets.symmetric(
          horizontal: _fabExtended ? 20 : 16,
        ),
        tooltip: 'New event',
        onPressed: () async {
          final result = await showQuickAddEventSheet(
            context,
            initialDate: selectedDay,
          );
          if (result == null) return;
          await ref
              .read(calendarControllerProvider)
              .addEvent(
                title: result.title,
                description: result.description,
                schedule: result.schedule,
                startTime: result.startTime,
                endTime: result.endTime,
                frequency: result.frequency,
                recurrenceEndDate: result.recurrenceEndDate,
                reminderEnabled: result.reminderEnabled,
                reminderMode: result.reminderMode,
                reminderMinutesBefore: result.reminderMinutesBefore,
              );
          if (!context.mounted) return;
          _acknowledgeEventSave(updated: false);
        },
        icon: const Icon(LucideIcons.plus),
        // The label folds away rather than snapping, so the button shrinks
        // to a round + without a jump.
        label: AnimatedSize(
          duration: AppMotion.of(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          child: _fabExtended
              ? const Text('New event')
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// "New event" with its label at first; just + once the person scrolls,
  /// so the button stops covering the list (and the agenda's Today chip).
  bool _fabExtended = true;

  ScrollDirection _lastScroll = ScrollDirection.idle;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final atTop =
        notification.metrics.pixels <= notification.metrics.minScrollExtent;
    if (notification is UserScrollNotification) {
      if (notification.direction != ScrollDirection.idle) {
        _lastScroll = notification.direction;
      }
      // Moving down the list folds it; pulling back to the top unfolds it.
      if (notification.direction == ScrollDirection.reverse && _fabExtended) {
        setState(() => _fabExtended = false);
      }
    } else if (notification is ScrollEndNotification &&
        atTop &&
        _lastScroll == ScrollDirection.forward &&
        !_fabExtended) {
      setState(() => _fabExtended = true);
    }
    return false;
  }

  /// Deletes one event or its whole series, then offers Undo.
  Future<void> _deleteWithUndo(
    _DeleteChoice choice,
    String eventId,
    String? recurrenceId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(calendarControllerProvider);
    final series = choice == _DeleteChoice.allInSeries && recurrenceId != null;
    final removed = series
        ? await controller.deleteEventSeries(recurrenceId)
        : await controller.deleteEvent(eventId);
    showUndoSnackBar(
      messenger,
      message: series ? 'Repeating event deleted' : 'Event deleted',
      onUndo: () => controller.restore(removed),
    );
  }

  /// Manual events (not tasks/habits/bills, which keep navigating to their
  /// own modules elsewhere) get tap-to-edit and swipe-to-delete.
  Widget _buildItemTile(
    BuildContext context,
    CalendarItem item, {
    bool agenda = false,
  }) {
    if (item.type != CalendarItemType.event || item.sourceId == null) {
      return CalendarItemTile(item: item, agenda: agenda);
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
        child: Icon(
          LucideIcons.trash2,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        final choice = await _confirmDelete(
          context,
          isPartOfSeries: recurrenceId != null,
        );
        if (choice == _DeleteChoice.cancel) return false;
        await _deleteWithUndo(choice, eventId, recurrenceId);
        return true;
      },
      child: CalendarItemTile(
        item: item,
        agenda: agenda,
        onTap: () => _editEvent(context, eventId),
      ),
    );
  }

  /// Offers "delete this event" alone for a standalone event, or a third
  /// "delete all events in this series" option when the event belongs to a
  /// recurring series (see the calendar delete-series plan notes).
  Future<_DeleteChoice> _confirmDelete(
    BuildContext context, {
    required bool isPartOfSeries,
  }) async {
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
              onPressed: () =>
                  Navigator.of(context).pop(_DeleteChoice.allInSeries),
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
    final repo = ref.read(calendarRepositoryProvider);
    final seriesRule = event.recurrenceId == null
        ? null
        : await repo.getSeriesSchedule(event);
    if (!context.mounted) return;
    final result = await showQuickAddEventSheet(
      context,
      seriesRule: seriesRule,
      initialDate: dateOnly(event.startTime),
      initial: event,
      onDelete: () async {
        final choice = await _confirmDelete(
          context,
          isPartOfSeries: event.recurrenceId != null,
        );
        if (choice == _DeleteChoice.cancel) return;
        await _deleteWithUndo(choice, eventId, event.recurrenceId);
      },
    );
    if (result == null) return;
    if (result.editFollowing) {
      await ref
          .read(calendarControllerProvider)
          .updateFollowingEvents(
            id: eventId,
            title: result.title,
            description: result.description,
            schedule: result.schedule!,
            startTime: result.startTime,
            endTime: result.endTime,
            reminderEnabled: result.reminderEnabled,
            reminderMode: result.reminderMode,
            reminderMinutesBefore: result.reminderMinutesBefore,
          );
      if (!context.mounted) return;
      _acknowledgeEventSave(updated: true);
      return;
    }
    await ref
        .read(calendarControllerProvider)
        .updateEvent(
          id: eventId,
          title: result.title,
          description: result.description,
          schedule: result.schedule,
          startTime: result.startTime,
          endTime: result.endTime,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
          reminderMinutesBefore: result.reminderMinutesBefore,
        );
    if (!context.mounted) return;
    _acknowledgeEventSave(updated: true);
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
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
