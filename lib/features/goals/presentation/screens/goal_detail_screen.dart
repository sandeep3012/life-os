import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../finance/application/finance_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../habits/application/habits_providers.dart';
import '../../application/goals_providers.dart';
import '../../domain/goal_progress.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_ring.dart';
import '../widgets/quick_add_goal_sheet.dart';

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
    final currencyCode = ref.watch(settingsProvider).currencyCode;
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
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editGoal(context, goal),
          ),
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
                  ? formatGoalValue(goal.type, goal.currentValue, currencyCode: currencyCode)
                  : '${formatGoalValue(goal.type, goal.currentValue, currencyCode: currencyCode)} / ${formatGoalValue(goal.type, goal.targetValue!, currencyCode: currencyCode)}',
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
          if (goal.reminderEnabled && goal.targetDate != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  goal.reminderDaysBefore == 0
                      ? 'Reminds you on the deadline'
                      : 'Reminds you ${goal.reminderDaysBefore} day${goal.reminderDaysBefore == 1 ? '' : 's'} before the deadline',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (data.links.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Linked to', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [for (final link in data.links) _LinkChip(link: link)],
            ),
          ],
          const SizedBox(height: 24),
          Text('Milestones', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _MilestonesSection(goalId: goal.id),
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, Goal goal) async {
    final habits = ref.read(habitsListProvider).value ?? const [];
    final accounts = ref.read(activeAccountsProvider);
    final result = await showQuickAddGoalSheet(
      context,
      habits: habits,
      accounts: accounts,
      currencySymbol: currencySymbolFor(ref.read(settingsProvider).currencyCode),
      initial: goal,
    );
    if (result == null) return;
    await ref.read(goalsControllerProvider).updateGoal(
      id: goal.id,
      title: result.title,
      type: result.type,
      targetValue: result.targetValue,
      targetDate: result.targetDate,
      reminderEnabled: result.reminderEnabled,
      reminderMode: result.reminderMode,
      reminderDaysBefore: result.reminderDaysBefore,
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

class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(goalMilestonesProvider(goalId)).value ?? const [];

    return Column(
      children: [
        for (final m in milestones)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: m.completed,
            onChanged: (v) =>
                ref.read(goalsControllerProvider).setMilestoneCompleted(m.id, v ?? false),
            title: Text(
              m.title,
              style: m.completed ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
            ),
            secondary: IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => ref.read(goalsControllerProvider).deleteMilestone(m.id),
            ),
          ),
        _AddMilestoneRow(goalId: goalId),
      ],
    );
  }
}

class _AddMilestoneRow extends ConsumerStatefulWidget {
  const _AddMilestoneRow({required this.goalId});

  final String goalId;

  @override
  ConsumerState<_AddMilestoneRow> createState() => _AddMilestoneRowState();
}

class _AddMilestoneRowState extends ConsumerState<_AddMilestoneRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    ref.read(goalsControllerProvider).createMilestone(goalId: widget.goalId, title: title);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Add a milestone'),
            onSubmitted: (_) => _submit(),
          ),
        ),
        IconButton(icon: const Icon(Icons.add_circle_outline_rounded), onPressed: _submit),
      ],
    );
  }
}
