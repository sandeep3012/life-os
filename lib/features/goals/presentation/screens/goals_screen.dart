import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_utils.dart';
import '../../../finance/application/finance_providers.dart';
import '../../../habits/application/habits_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../application/goals_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/quick_add_goal_sheet.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsWithLinksProvider);
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_rounded, size: 48, color: theme.colorScheme.primary)
                        .animate()
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.0, 1.0),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: const Duration(milliseconds: 250)),
                    const SizedBox(height: 16),
                    Text(
                      'No goals yet — add one to start tracking progress.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 250.ms)
                        .slideY(begin: 0.1, end: 0, duration: 250.ms),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: goals.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = goals[index];
                return GoalCard(
                  data: data,
                  currencyCode: currencyCode,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GoalDetailScreen(goalId: data.goal.id),
                    ),
                  ),
                )
                    .animate(delay: (index * 30).ms)
                    .fadeIn(duration: 200.ms)
                    .slideY(begin: 0.05, end: 0, duration: 200.ms);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addGoal(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
    );
  }

  Future<void> _addGoal(BuildContext context, WidgetRef ref) async {
    final habits = ref.read(habitsListProvider).value ?? const [];
    final accounts = ref.read(activeAccountsProvider);
    final result = await showQuickAddGoalSheet(
      context,
      habits: habits,
      accounts: accounts,
      currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
    );
    if (result == null) return;
    final goalId = await ref.read(goalsControllerProvider).createGoal(
      title: result.title,
      type: result.type,
      targetValue: result.targetValue,
      targetDate: result.targetDate,
      reminderEnabled: result.reminderEnabled,
      reminderMode: result.reminderMode,
      reminderDaysBefore: result.reminderDaysBefore,
    );
    if (result.link != null) {
      await ref.read(goalsControllerProvider).addLink(
        goalId: goalId,
        linkedType: result.link!.type,
        linkedId: result.link!.id,
      );
    }
  }
}

