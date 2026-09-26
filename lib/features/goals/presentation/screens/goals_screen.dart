import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/router/app_sidebar.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/collection_layout.dart';
import '../../../../core/widgets/filter_pill.dart';
import '../../../../core/widgets/inline_add_button.dart';
import '../../../../core/widgets/tab_rail.dart';
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

/// Which goals the list shows by status. Defaults to [active], so finished
/// and dropped goals stop crowding the list but stay one tap away.
enum _StatusFilter { active, completed, abandoned, all }

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  _StatusFilter _status = _StatusFilter.active;

  /// `financial` | `habit` | `generic`, or null for every type.
  String? _type;

  /// Independent of [_type]: a goal's type and whether its progress is
  /// derived from links are separate properties, so "Habit + auto-tracked"
  /// is a meaningful combination.
  bool _autoOnly = false;

  static const _types = {
    'financial': 'Financial',
    'habit': 'Habit',
    'generic': 'Generic',
  };

  bool get _filtered =>
      _status != _StatusFilter.active || _type != null || _autoOnly;

  void _clearFilters() => setState(() {
    _status = _StatusFilter.active;
    _type = null;
    _autoOnly = false;
  });

  bool _matches(Goal goal) {
    final statusOk = switch (_status) {
      _StatusFilter.all => true,
      _StatusFilter.active => goal.status == 'active',
      _StatusFilter.completed => goal.status == 'completed',
      _StatusFilter.abandoned => goal.status == 'abandoned',
    };
    return statusOk &&
        (_type == null || goal.type == _type) &&
        (!_autoOnly || goal.progressMode == 'automatic');
  }

  /// Whether the list's inline "Build a new goal" row is on screen; the FAB
  /// shows only while it is not — the same one-affordance rule as the Planner.
  bool _inlineAddVisible = false;

  void _onInlineAddVisibility(bool visible) {
    if (!mounted || _inlineAddVisible == visible) return;
    setState(() => _inlineAddVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    final allGoals = ref.watch(goalsWithLinksProvider);
    final goals = allGoals.where((g) => _matches(g.goal)).toList();
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
      body: allGoals.isEmpty
          // Nothing to filter yet — no filter bar, just the first-run prompt.
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
          : Column(
              children: [
                // Fixed above the list, so the active filter is always in view.
                _GoalFilters(
                  status: _status,
                  type: _type,
                  autoOnly: _autoOnly,
                  types: _types,
                  onStatus: (v) => setState(() => _status = v),
                  onType: (v) => setState(() => _type = v),
                  onAutoOnly: (v) => setState(() => _autoOnly = v),
                ),
                Expanded(
                  child: goals.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(32, 32, 32, 8),
                              child: Text(
                                'No goals match these filters.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_filtered)
                              Center(
                                child: TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('Clear filters'),
                                ),
                              ),
                            addButton,
                          ],
                        )
                      : CollectionView(
                          layout: layout,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
                                  builder: (_) =>
                                      GoalDetailScreen(goalId: data.goal.id),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
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

/// Status as a segmented rail, then type and tracking as a scrolling chip row.
class _GoalFilters extends StatelessWidget {
  const _GoalFilters({
    required this.status,
    required this.type,
    required this.autoOnly,
    required this.types,
    required this.onStatus,
    required this.onType,
    required this.onAutoOnly,
  });

  final _StatusFilter status;
  final String? type;
  final bool autoOnly;
  final Map<String, String> types;
  final ValueChanged<_StatusFilter> onStatus;
  final ValueChanged<String?> onType;
  final ValueChanged<bool> onAutoOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppTabRail<_StatusFilter>(
              value: status,
              labels: const {
                _StatusFilter.active: 'Active',
                _StatusFilter.completed: 'Completed',
                _StatusFilter.abandoned: 'Abandoned',
                _StatusFilter.all: 'All',
              },
              height: 36,
              fontSize: 12.5,
              onChanged: onStatus,
            ),
          ),
          const SizedBox(height: 10),
          // A wrap, not a sideways scroll: at phone width the last chip —
          // the tracking toggle — would otherwise sit off-screen, unseen.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterPill(
                  label: 'All types',
                  selected: type == null,
                  onTap: () => onType(null),
                ),
                for (final entry in types.entries)
                  FilterPill(
                    label: entry.value,
                    selected: type == entry.key,
                    // Tapping the active type again clears it, as in Documents.
                    onTap: () => onType(type == entry.key ? null : entry.key),
                  ),
                FilterPill(
                  label: 'Auto-tracked',
                  icon: LucideIcons.refreshCw,
                  selected: autoOnly,
                  onTap: () => onAutoOnly(!autoOnly),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
