import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/calendar_item.dart';
import '../../../../app/theme/app_fonts.dart';

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
  const CalendarItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.agenda = false,
  });

  final CalendarItem item;
  final VoidCallback? onTap;
  final bool agenda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorForCalendarItemType(context, item.type);
    final timeLabel = item.time == null
        ? 'All day'
        : item.endTime == null || agenda
        ? DateFormat.jm().format(item.time!)
        : '${DateFormat.jm().format(item.time!)} – ${DateFormat.jm().format(item.endTime!)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: agenda ? 16 : 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: agenda ? 76 : 60,
              child: Text(
                agenda && item.time != null && item.endTime != null
                    ? '$timeLabel\n${_durationLabel(item.endTime!.difference(item.time!))}'
                    : timeLabel,
                style: TextStyle(
                  fontFamily: AppFonts.numeric,
                  fontFeatures: AppFonts.tabular,
                  fontSize: agenda ? 12 : 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Container(
              width: agenda ? 4 : 3,
              height: agenda ? 40 : 32,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.reminderEnabled) ...[
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.bellRing,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                      if (agenda && item.recurrenceId != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          LucideIcons.repeat,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
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
      ),
    );
  }

  String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes <= 0) return '';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours == 0) return '$minutes min';
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }
}
