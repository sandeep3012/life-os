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
  const AccountCard({super.key, required this.account, this.onTap});

  final Account account;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final negative = account.balanceMinor < 0;
    final dotColor = negative ? colors.critical : colors.finance;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Opacity(
            opacity: account.isActive ? 1 : 0.55,
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
          ),
        ),
      ),
    );
  }
}

/// The outlined "add another account" tile appended to the account row —
/// always present, unlike the old FAB-only entry point that disappeared
/// after the first account was created.
class AddAccountCard extends StatelessWidget {
  const AddAccountCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 160,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(height: 4),
              Text(
                'Add account',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
