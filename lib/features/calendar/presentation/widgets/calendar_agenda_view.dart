import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/calendar_item.dart';
import 'calendar_item_tile.dart';

enum CalendarAgendaFilter {
  all('All', null),
  tasks('Tasks', CalendarItemType.task),
  habits('Habits', CalendarItemType.habit),
  events('Events', CalendarItemType.event);

  const CalendarAgendaFilter(this.label, this.type);
  final String label;
  final CalendarItemType? type;
}

Map<DateTime, List<CalendarItem>> groupCalendarAgendaItems(
  List<CalendarItem> items,
  CalendarAgendaFilter filter,
) {
  final groups = <DateTime, List<CalendarItem>>{};
  for (final item in items) {
    if (filter.type != null && item.type != filter.type) continue;
    groups.putIfAbsent(dateOnly(item.date), () => []).add(item);
  }
  for (final group in groups.values) {
    group.sort((a, b) {
      // Keep the existing calendar's ordering: timed entries, then all-day.
      if (a.time == null && b.time != null) return 1;
      if (a.time != null && b.time == null) return -1;
      final timeOrder = a.time == null ? 0 : a.time!.compareTo(b.time!);
      return timeOrder != 0 ? timeOrder : a.title.compareTo(b.title);
    });
  }
  return groups;
}

/// A date-anchored, bidirectional agenda. Slivers build only nearby dates;
/// navigating to a distant date does not render every intervening entry.
class CalendarAgendaView extends StatefulWidget {
  const CalendarAgendaView({
    super.key,
    required this.items,
    required this.selectedDay,
    required this.onDayChanged,
    required this.itemBuilder,
  });

  final List<CalendarItem> items;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayChanged;
  final Widget Function(BuildContext, CalendarItem) itemBuilder;

  @override
  State<CalendarAgendaView> createState() => _CalendarAgendaViewState();
}

class _CalendarAgendaViewState extends State<CalendarAgendaView> {
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _viewportKey = GlobalKey();
  static const _centerKey = ValueKey('agenda-center');
  final _dayKeys = <DateTime, GlobalKey>{};
  CalendarAgendaFilter _filter = CalendarAgendaFilter.all;
  late DateTime _anchorDay;
  late DateTime _focusedDay;
  bool _syncScheduled = false;
  bool _reanchoring = false;
  bool _todayVisible = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _anchorDay = dateOnly(widget.selectedDay);
    _focusedDay = _anchorDay;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectDay(DateTime date) {
    final day = dateOnly(date);
    setState(() => _focusedDay = day);
    widget.onDayChanged(day);
  }

  void _goToDay(DateTime date) {
    final day = dateOnly(date);
    _reanchoring = true;
    // Re-anchor even for empty dates so a tap never silently selects another
    // day's items. Older and newer populated dates remain scrollable.
    setState(() {
      _anchorDay = day;
      _generation++;
      _dayKeys.clear();
    });
    _selectDay(day);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reanchoring = false;
      _scheduleDateSync();
    });
  }

  void _scheduleDateSync() {
    if (_syncScheduled || _reanchoring) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || _reanchoring) return;
      final viewport = _viewportKey.currentContext?.findRenderObject();
      if (viewport is! RenderBox || !viewport.hasSize) return;
      final top = viewport.localToGlobal(Offset.zero).dy;
      final bottom = top + viewport.size.height;
      DateTime? visibleDay;
      var todayVisible = false;
      final today = dateOnly(DateTime.now());
      double firstTop = double.infinity;
      for (final entry in _dayKeys.entries) {
        final box = entry.value.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached || !box.hasSize) continue;
        final sectionTop = box.localToGlobal(Offset.zero).dy;
        final sectionBottom = sectionTop + box.size.height;
        if (entry.key == today &&
            sectionBottom > top + 1 &&
            sectionTop < bottom) {
          todayVisible = true;
        }
        if (sectionBottom > top + 1 &&
            sectionTop < bottom &&
            sectionTop < firstTop) {
          firstTop = sectionTop;
          visibleDay = entry.key;
        }
      }
      if (visibleDay != null && visibleDay != widget.selectedDay) {
        _selectDay(visibleDay);
      }
      if (_todayVisible != todayVisible) {
        setState(() => _todayVisible = todayVisible);
      }
    });
    // A re-anchor can request measurement from a post-frame callback. Ensure
    // that measurement gets a frame even when no scroll animation is running.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = groupCalendarAgendaItems(widget.items, _filter);
    final days = {...groups.keys, _anchorDay, dateOnly(DateTime.now())}.toList()
      ..sort();
    _scheduleDateSync();
    final earlier = days
        .where((day) => day.isBefore(_anchorDay))
        .toList()
        .reversed
        .toList();
    final later = days.where((day) => !day.isBefore(_anchorDay)).toList();
    _dayKeys.removeWhere((day, _) => !days.contains(day));
    final firstDay = days.first.isBefore(DateTime(2020))
        ? days.first
        : DateTime(2020);
    final lastDay = days.last.isAfter(DateTime(2035))
        ? days.last
        : DateTime(2035);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              for (final filter in CalendarAgendaFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    onSelected: (_) {
                      if (_filter == filter) return;
                      setState(() => _filter = filter);
                      _goToDay(widget.selectedDay);
                    },
                  ),
                ),
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TableCalendar<CalendarItemType>(
              focusedDay: _focusedDay,
              firstDay: firstDay,
              lastDay: lastDay,
              calendarFormat: CalendarFormat.week,
              pageAnimationEnabled: false,
              availableCalendarFormats: const {CalendarFormat.week: 'Week'},
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) =>
                  dateOnly(day) == widget.selectedDay,
              onDaySelected: (selected, _) => _goToDay(selected),
              onPageChanged: (focused) => setState(() => _focusedDay = focused),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                headerPadding: EdgeInsets.symmetric(vertical: 4),
                leftChevronIcon: Icon(LucideIcons.chevronLeft),
                rightChevronIcon: Icon(LucideIcons.chevronRight),
              ),
              eventLoader: (day) =>
                  (groups[dateOnly(day)] ?? const <CalendarItem>[])
                      .map((item) => item.type)
                      .toSet()
                      .toList(),
              calendarStyle: CalendarStyle(
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
                selectedTextStyle: TextStyle(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                headerTitleBuilder: (context, day) => Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (final entry in const {
                      CalendarItemType.task: 'Task',
                      CalendarItemType.habit: 'Habit',
                      CalendarItemType.event: 'Event',
                    }.entries)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: colorForCalendarItemType(
                                context,
                                entry.key,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.value,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                markerBuilder: (context, day, types) => types.isEmpty
                    ? null
                    : Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final type in types)
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
                      ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification.depth == 0) _scheduleDateSync();
                          return false;
                        },
                        child: SizedBox(
                          key: _viewportKey,
                          child: CustomScrollView(
                            key: ValueKey(_generation),
                            controller: _scrollController,
                            center: _centerKey,
                            slivers: [
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      _daySection(earlier[index], groups),
                                  childCount: earlier.length,
                                  findChildIndexCallback: (key) =>
                                      _indexForKey(key, earlier),
                                ),
                              ),
                              SliverList(
                                key: _centerKey,
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _daySection(
                                    later[index],
                                    groups,
                                    minimumHeight: index == later.length - 1
                                        ? constraints.maxHeight
                                        : 0,
                                  ),
                                  childCount: later.length,
                                  findChildIndexCallback: (key) =>
                                      _indexForKey(key, later),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ),
              ),
              if (!_todayVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  // Match the Scaffold's end-float FAB bottom margin. Remove
                  // the chip's invisible tap-target padding so visible edges align.
                  bottom:
                      kFloatingActionButtonMargin +
                      MediaQuery.viewPaddingOf(context).bottom,
                  child: Center(
                    child: ActionChip(
                      key: const ValueKey('agenda-today-action'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      avatar: Icon(
                        widget.selectedDay.isBefore(dateOnly(DateTime.now()))
                            ? LucideIcons.arrowDown
                            : LucideIcons.arrowUp,
                        size: 16,
                      ),
                      label: const Text('Today'),
                      onPressed: () => _goToDay(DateTime.now()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  int? _indexForKey(Key key, List<DateTime> days) {
    if (key is! ValueKey<DateTime>) return null;
    final index = days.indexOf(key.value);
    return index < 0 ? null : index;
  }

  Widget _daySection(
    DateTime day,
    Map<DateTime, List<CalendarItem>> groups, {
    double minimumHeight = 0,
  }) {
    final theme = Theme.of(context);
    final items = groups[day] ?? const <CalendarItem>[];
    final today = dateOnly(DateTime.now());
    final label = day == today
        ? 'Today'
        : day == DateTime(today.year, today.month, today.day + 1)
        ? 'Tomorrow'
        : DateFormat.EEEE().format(day);
    return KeyedSubtree(
      key: ValueKey(day),
      // Let the final date align at the top, without scrolling into a blank page.
      child: ConstrainedBox(
        key: _dayKeys.putIfAbsent(day, GlobalKey.new),
        constraints: BoxConstraints(minHeight: minimumHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, minimumHeight > 0 ? 100 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    DateFormat(
                      day.year == today.year ? 'd MMM' : 'd MMM y',
                    ).format(day),
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _filter == CalendarAgendaFilter.all
                        ? 'Nothing scheduled for this day.'
                        : 'No ${_filter.label.toLowerCase()} for this day.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final item in items) widget.itemBuilder(context, item),
            ],
          ),
        ),
      ),
    );
  }
}
