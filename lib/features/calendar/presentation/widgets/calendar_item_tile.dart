import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/calendar_item.dart';

Color colorForCalendarItemType(BuildContext context, CalendarItemType type) {
  final colors = context.appColors;
  return switch (type) {
    CalendarItemType.task => colors.tasks,
    CalendarItemType.habit => colors.habits,
    CalendarItemType.event => colors.calendar,
    CalendarItemType.bill => colors.finance,
  };
}

class CalendarItemTile extends StatelessWidget {
  const CalendarItemTile({super.key, required this.item});

  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorForCalendarItemType(context, item.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              item.time != null ? DateFormat.jm().format(item.time!) : 'All day',
              style: TextStyle(
                fontFamily: 'PlexMono',
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  item.subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
