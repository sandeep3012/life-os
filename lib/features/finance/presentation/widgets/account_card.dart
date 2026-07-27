import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';

IconData accountIcon(String type) => switch (type) {
  'checking' => Icons.account_balance_wallet_rounded,
  'savings' => Icons.savings_rounded,
  'credit_card' => Icons.credit_card_rounded,
  'investment' => Icons.trending_up_rounded,
  _ => Icons.payments_rounded,
};

class AccountCard extends StatelessWidget {
  const AccountCard({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final negative = account.balanceMinor < 0;
    final dotColor = negative ? colors.critical : colors.finance;
    final theme = Theme.of(context);

    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  account.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatMinor(account.balanceMinor, showDecimals: false),
            style: TextStyle(
              fontFamily: 'PlexMono',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: negative ? colors.critical : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
