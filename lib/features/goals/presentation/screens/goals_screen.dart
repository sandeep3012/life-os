import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../finance/application/finance_providers.dart';
import '../../../habits/application/habits_providers.dart';
import '../../application/goals_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/quick_add_goal_sheet.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsWithLinksProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No goals yet — add one to start tracking progress.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GoalDetailScreen(goalId: data.goal.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final habits = ref.read(habitsListProvider).value ?? const [];
          final accounts = ref.read(activeAccountsProvider);
          final result = await showQuickAddGoalSheet(context, habits: habits, accounts: accounts);
          if (result == null) return;
          final goalId = await ref.read(goalsControllerProvider).createGoal(
            title: result.title,
            type: result.type,
            targetValue: result.targetValue,
          );
          if (result.link != null) {
            await ref.read(goalsControllerProvider).addLink(
              goalId: goalId,
              linkedType: result.link!.type,
              linkedId: result.link!.id,
            );
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
    );
  }
}
