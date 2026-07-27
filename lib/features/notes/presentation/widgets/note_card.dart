import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, this.folder, required this.onTap});

  final Note note;
  final Folder? folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                note.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (folder != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        folder!.name,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    _relativeTime(note.updatedAt),
                    style: TextStyle(fontSize: 10.5, color: colors.notes),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    if (isSameDay(dt, now)) {
      final hours = now.difference(dt).inHours;
      if (hours < 1) return '${now.difference(dt).inMinutes}m ago';
      return '${hours}h ago';
    }
    if (isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    final days = now.difference(dt).inDays;
    if (days < 7) return '${days}d ago';
    return DateFormat.MMMd().format(dt);
  }
}
