import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  PaymentMode('upi', 'UPI', LucideIcons.qrCode),
  PaymentMode('cash', 'Cash', LucideIcons.banknote),
  PaymentMode('card', 'Card', LucideIcons.creditCard),
  PaymentMode('net_banking', 'Net Banking', LucideIcons.landmark),
  PaymentMode('other', 'Other', LucideIcons.ellipsis),
];

final _paymentModeById = {for (final m in paymentModes) m.id: m};

PaymentMode? paymentModeById(String? id) => id == null ? null : _paymentModeById[id];
