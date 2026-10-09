import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/finance/application/finance_providers.dart';
import 'sound_effects.dart';

/// Sounds the budget alert when spending pushes a budget over its limit —
/// at the moment it crosses, once. Budgets already over when the app opens
/// are the starting point, not news, so they stay quiet.
class BudgetAlertSound {
  BudgetAlertSound(this._ref);

  final Ref _ref;

  /// Budgets over their limit last time we looked; null until the budgets,
  /// categories and transactions have all loaded, so a half-loaded first
  /// read can't make every over-budget category look newly crossed.
  Set<String>? _over;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _ref.listen(budgetsWithProgressProvider, (_, progress) {
      final loaded =
          _ref.read(budgetsProvider).hasValue &&
          _ref.read(categoriesProvider).hasValue &&
          _ref.read(transactionsProvider).hasValue;
      final over = {
        for (final p in progress)
          if (p.isOver) p.budget.id,
      };
      final previous = _over;
      if (!loaded) return;
      _over = over;
      if (previous != null && over.difference(previous).isNotEmpty) {
        _ref.read(soundEffectsProvider).play(SoundEffect.budgetAlert);
      }
    }, fireImmediately: true);
  }
}

final budgetAlertSoundProvider = Provider<BudgetAlertSound>(
  BudgetAlertSound.new,
);
