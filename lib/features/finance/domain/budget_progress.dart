import '../../../core/database/app_database.dart';

/// A budget paired with its category and how much has actually been spent
/// against it this period — computed from [Transactions] rather than
/// stored, same as habit streaks, so it can't drift out of sync.
class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.category,
    required this.spentMinor,
  });

  final Budget budget;
  final Category category;
  final int spentMinor;

  int get limitMinor => budget.limitMinor;
  double get ratio => limitMinor == 0 ? 0 : spentMinor / limitMinor;
  bool get isOver => spentMinor > limitMinor;
}
