import '../../finance/domain/payment_mode.dart';

class PaymentModeSpend {
  const PaymentModeSpend({required this.mode, required this.totalMinor, required this.share});

  /// Null for spend recorded without a payment mode ("Not set").
  final PaymentMode? mode;
  final int totalMinor;

  /// 0..1 of this mode's spend against the month's total spend — the same
  /// total "By category" shows.
  final double share;
}
