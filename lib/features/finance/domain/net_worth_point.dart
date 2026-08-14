/// One point on the net worth trend — assets and liabilities as of [date],
/// derived (never stored) from account balances and transaction history.
/// See `computeNetWorthTrend` in `finance_providers.dart`.
class NetWorthPoint {
  const NetWorthPoint({
    required this.date,
    required this.assetsMinor,
    required this.liabilitiesMinor,
  });

  final DateTime date;
  final int assetsMinor;
  final int liabilitiesMinor;

  int get netWorthMinor => assetsMinor - liabilitiesMinor;
}
