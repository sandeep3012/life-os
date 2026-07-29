import '../../finance/domain/payment_mode.dart';

class PaymentModeSpend {
  const PaymentModeSpend({required this.mode, required this.totalMinor, required this.share});

  final PaymentMode mode;
  final int totalMinor;

  /// 0..1 of this mode's spend against the month's total (tagged spend
  /// only — see [PaymentModeSpend]'s provider for how untagged transactions
  /// are handled).
  final double share;
}
