import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../domain/payment_mode.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, this.category, this.onEdit});

  final Transaction transaction;
  final Category? category;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final isIncome = transaction.amountMinor >= 0;
    final color = category != null
        ? Color(int.parse(category!.colorHex.replaceFirst('#', '0xFF')))
        : (isIncome ? colors.good : colors.spend);
    final mode = paymentModeById(transaction.paymentMode);

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(
                category != null ? resolveIcon(category!.icon) : Icons.swap_horiz_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.merchant,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${category?.name ?? 'Uncategorized'} · ${_relativeDate(transaction.date)}',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (mode != null) ...[
                        const SizedBox(width: 6),
                        Icon(mode.icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              formatMinor(transaction.amountMinor, showSign: isIncome),
              style: TextStyle(
                fontFamily: 'PlexMono',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isIncome ? colors.good : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.03, end: 0, duration: 200.ms);
  }

  static String _relativeDate(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return 'Today';
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat.MMMd().format(date);
  }
}
