import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../finance/application/finance_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../application/goals_providers.dart';
import '../../domain/goal_progress.dart';
import '../widgets/goal_card.dart';
import '../widgets/goal_ring.dart';
import '../widgets/quick_add_goal_sheet.dart';
import '../../../../app/theme/app_fonts.dart';

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
    final all = ref.watch(goalsWithLinksProvider);
    final data = all.where((g) => g.goal.id == widget.goalId).firstOrNull;

    if (data == null) {
      return const Scaffold(body: Center(child: Text('Goal not found')));
    }

    final goal = data.goal;
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final step = goal.type == 'financial' ? 1000.0 : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil),
            onPressed: () => _editGoal(context, goal),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
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
          Center(
            child: GoalRing(ratio: data.ratio, size: 120, strokeWidth: 12),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              !data.progressReady
                  ? 'Waiting for linked data…'
                  : goal.targetValue == null
                  ? formatGoalValue(
                      goal.type,
                      goal.currentValue,
                      currencyCode: currencyCode,
                    )
                  : '${formatGoalValue(goal.type, goal.currentValue, currencyCode: currencyCode)} / ${formatGoalValue(goal.type, goal.targetValue!, currencyCode: currencyCode)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: AppFonts.numeric,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Automatic progress'),
            subtitle: Text(switch (goal.type) {
              'financial' =>
                'Sum of linked account balances in $currencyCode. Spending reduces progress; other currencies are excluded.',
              'habit' =>
                'Scheduled check-ins for linked habits since this goal was created.',
              _ => 'Number of completed linked tasks.',
            }),
            value: goal.progressMode == 'automatic',
            onChanged: (value) async {
              try {
                await ref
                    .read(goalsRepositoryProvider)
                    .setAutomaticProgress(goal.id, value);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not change progress mode.'),
                    ),
                  );
                }
              }
            },
          ),
          if (goal.progressMode == 'automatic')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Updates from linked records. Switching off restores your last manually entered value.',
              ),
            ),
          if (goal.progressMode != 'automatic')
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(LucideIcons.minus),
                  onPressed: () => ref
                      .read(goalsControllerProvider)
                      .updateProgress(
                        goal.id,
                        (goal.currentValue - step).clamp(0, double.infinity),
                      ),
                ),
                const SizedBox(width: 16),
                IconButton.filledTonal(
                  icon: const Icon(LucideIcons.plus),
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
                  LucideIcons.bell,
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
          TextButton.icon(
            onPressed: () => _addLink(goal),
            icon: const Icon(LucideIcons.link),
            label: const Text('Link a record'),
          ),
          const SizedBox(height: 24),
          Text('Milestones', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _MilestonesSection(goalId: goal.id),
        ],
      ),
    );
  }

  Future<void> _addLink(Goal goal) async {
    final type = switch (goal.type) {
      'financial' => 'account',
      'habit' => 'habit',
      _ => 'task',
    };
    final existing = ref.read(allGoalLinksProvider).value ?? const [];
    final options =
        <(String, String)>[
              if (type == 'account')
                for (final a in ref.read(accountsProvider).value ?? <Account>[])
                  (a.id, '${a.name} (${a.currencyCode})'),
              if (type == 'habit')
                for (final h
                    in (ref.read(goalHabitsProvider).value ?? <Habit>[]).where(
                      (h) => !h.archived,
                    ))
                  (h.id, h.name),
              if (type == 'task')
                for (final t in ref.read(allTasksProvider).value ?? <Task>[])
                  (t.id, t.title),
            ]
            .where(
              (item) => !existing.any(
                (l) =>
                    l.goalId == goal.id &&
                    l.linkedType == type &&
                    l.linkedId == item.$1,
              ),
            )
            .toList();
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Link a $type'),
        children: options.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No available records. Create one first.'),
                ),
              ]
            : [
                for (final option in options)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, option.$1),
                    child: Text(option.$2),
                  ),
              ],
      ),
    );
    if (selected == null) return;
    try {
      await ref
          .read(goalsControllerProvider)
          .addLink(goalId: goal.id, linkedType: type, linkedId: selected);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not link this record.')),
        );
      }
    }
  }

  Future<void> _editGoal(BuildContext context, Goal goal) async {
    final habits = (ref.read(goalHabitsProvider).value ?? const <Habit>[])
        .where((h) => !h.archived)
        .toList();
    final accounts = ref.read(activeAccountsProvider);
    final result = await showQuickAddGoalSheet(
      context,
      habits: habits,
      accounts: accounts,
      currencySymbol: currencySymbolFor(
        ref.read(settingsProvider).currencyCode,
      ),
      initial: goal,
    );
    if (result == null) return;
    await ref
        .read(goalsControllerProvider)
        .updateGoal(
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
      onDeleted: () =>
          ref.read(goalsControllerProvider).removeLink(link.linkId),
    );
  }
}

class _MilestonesSection extends ConsumerWidget {
  const _MilestonesSection({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones =
        ref.watch(goalMilestonesProvider(goalId)).value ?? const [];

    return Column(
      children: [
        for (final m in milestones)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: m.completed,
            onChanged: (v) => ref
                .read(goalsControllerProvider)
                .setMilestoneCompleted(m.id, v ?? false),
            title: Text(
              m.title,
              style: m.completed
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            secondary: IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () =>
                  ref.read(goalsControllerProvider).deleteMilestone(m.id),
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
    ref
        .read(goalsControllerProvider)
        .createMilestone(goalId: widget.goalId, title: title);
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
        IconButton(
          icon: const Icon(LucideIcons.circlePlus),
          onPressed: _submit,
        ),
      ],
    );
  }
}
