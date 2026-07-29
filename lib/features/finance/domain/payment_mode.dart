import 'package:flutter/material.dart';

/// A small fixed set of payment modes — unlike categories/account types,
/// not user-manageable (there's no useful "custom payment mode" the way
/// there's a useful custom category), so this is a plain constant table
/// rather than a database-backed one.
class PaymentMode {
  const PaymentMode(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const paymentModes = [
  PaymentMode('upi', 'UPI', Icons.qr_code_rounded),
  PaymentMode('cash', 'Cash', Icons.payments_rounded),
  PaymentMode('card', 'Card', Icons.credit_card_rounded),
  PaymentMode('net_banking', 'Net Banking', Icons.account_balance_rounded),
  PaymentMode('other', 'Other', Icons.more_horiz_rounded),
];

final _paymentModeById = {for (final m in paymentModes) m.id: m};

PaymentMode? paymentModeById(String? id) => id == null ? null : _paymentModeById[id];
