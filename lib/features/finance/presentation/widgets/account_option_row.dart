import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import 'account_card.dart' show accountIconValueFor;

/// The gap between a dropdown row's glyph and its label.
///
/// Shared by the account and category dropdowns so every picker in the app
/// lines up the same way.
const dropdownIconGap = 12.0;

/// One row of an account or category dropdown: glyph, gap, label.
///
/// Account rows carry their own account-type icon rather than the field
/// repeating one static glyph — with a per-row icon a `prefixIcon` would just
/// show a second, unrelated one beside the selected account.
class OptionRow extends StatelessWidget {
  const OptionRow({super.key, required this.icon, required this.label});

  /// Builds a row for [account], using its type's icon.
  factory OptionRow.account(Account account, List<AccountType> types) =>
      OptionRow(
        icon: IconOrEmoji(
          value: accountIconValueFor(account.type, types),
          size: 16,
        ),
        label: account.name,
      );

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: dropdownIconGap),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
