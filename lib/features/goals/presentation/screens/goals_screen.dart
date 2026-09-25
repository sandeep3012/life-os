import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/collection_layout.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../finance/application/finance_providers.dart';
import '../../../settings/application/settings_providers.dart';
import '../../../../core/widgets/save_feedback.dart';
import '../../application/goals_providers.dart';
import '../widgets/goal_card.dart';
import '../widgets/quick_add_goal_sheet.dart';
import 'goal_detail_screen.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  /// Whether the list's inline "Build a new goal" row is on screen; the FAB
  /// shows only while it is not — the same one-affordance rule as the Planner.
  bool _inlineAddVisible = false;

  void _onInlineAddVisibility(bool visible) {
    if (!mounted || _inlineAddVisible == visible) return;
    setState(() => _inlineAddVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(goalsWithLinksProvider);
    final currencyCode = ref.watch(settingsProvider).currencyCode;
    final theme = Theme.of(context);
    final layout = ref.watch(
      collectionLayoutsProvider,
    )[CollectionScreen.goals]!;
    final addButton = InlineAddButton(
      label: 'Build a new goal',
      onTap: _addGoal,
      onVisibilityChanged: _onInlineAddVisibility,
      padding: const EdgeInsets.only(top: 4),
    );

    return Scaffold(
      drawer: const AppSidebar(),
      appBar: AppBar(
        title: const Text('Goals'),
        actions: const [CollectionLayoutButton(screen: CollectionScreen.goals)],
      ),
      body: goals.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No goals yet — add one to start tracking progress.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                addButton,
              ],
            )
          : CollectionView(
              layout: layout,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: goals.length,
              footer: addButton,
              itemBuilder: (context, index) {
                final data = goals[index];
                return GoalCard(
                  grid: layout == CollectionLayout.grid,
                  data: data,
                  currencyCode: currencyCode,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GoalDetailScreen(goalId: data.goal.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _inlineAddVisible
          ? null
          : FloatingActionButton.extended(
              onPressed: _addGoal,
              icon: const Icon(LucideIcons.plus),
              label: const Text('New goal'),
            ),
    );
  }

  Future<void> _addGoal() async {
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
    );
    if (result == null) return;
    final goalId = await ref
        .read(goalsControllerProvider)
        .createGoal(
          title: result.title,
          type: result.type,
          targetValue: result.targetValue,
          targetDate: result.targetDate,
          reminderEnabled: result.reminderEnabled,
          reminderMode: result.reminderMode,
          reminderDaysBefore: result.reminderDaysBefore,
        );
    if (result.link != null) {
      await ref
          .read(goalsControllerProvider)
          .addLink(
            goalId: goalId,
            linkedType: result.link!.type,
            linkedId: result.link!.id,
          );
    }
    // Same wording as the add menu's goal path, which already acknowledged —
    // this screen's own "New goal" button was the one that saved silently.
    if (!mounted) return;
    await showSaveFeedback(
      context,
      ref,
      title: 'Goal saved',
      message: '“${result.title}” is being tracked.',
    );
  }
}
