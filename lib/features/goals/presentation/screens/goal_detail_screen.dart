import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/goals_providers.dart';
import '../../domain/goal_progress.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_ring.dart';

class GoalDetailScreen extends ConsumerStatefulWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends ConsumerState<GoalDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final all = ref.watch(goalsWithLinksProvider);
    final data = all.where((g) => g.goal.id == widget.goalId).firstOrNull;

    if (data == null) {
      return const Scaffold(body: Center(child: Text('Goal not found')));
    }

    final goal = data.goal;
    final color = switch (goal.type) {
      'financial' => colors.finance,
      'habit' => colors.habits,
      _ => colors.goals,
    };
    final step = goal.type == 'financial' ? 1000.0 : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              await ref.read(goalsControllerProvider).deleteGoal(goal.id);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: GoalRing(ratio: data.ratio, color: color, size: 120, strokeWidth: 12)),
          const SizedBox(height: 20),
          Center(
            child: Text(
              goal.targetValue == null
                  ? formatGoalValue(goal.type, goal.currentValue)
                  : '${formatGoalValue(goal.type, goal.currentValue)} / ${formatGoalValue(goal.type, goal.targetValue!)}',
              style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'PlexMono'),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.remove_rounded),
                onPressed: () => ref
                    .read(goalsControllerProvider)
                    .updateProgress(goal.id, (goal.currentValue - step).clamp(0, double.infinity)),
              ),
              const SizedBox(width: 16),
              IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => ref
                    .read(goalsControllerProvider)
                    .updateProgress(goal.id, goal.currentValue + step),
              ),
            ],
          ),
          if (data.links.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Linked to', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [for (final link in data.links) _LinkChip(link: link)],
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkChip extends ConsumerWidget {
  const _LinkChip({required this.link});

  final GoalLinkInfo link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Chip(
      label: Text(link.label),
      onDeleted: () => ref.read(goalsControllerProvider).removeLink(link.linkId),
    );
  }
}
