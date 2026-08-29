import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_lookup.dart';
import '../../application/habits_providers.dart';

/// A dedicated destination makes it clear that the user is viewing inactive
/// habits and gives them an ordinary navigation path back to active habits.
class ArchivedHabitsScreen extends ConsumerWidget {
  const ArchivedHabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedHabitsProvider).value ?? const [];
    final categories = ref.watch(habitCategoriesProvider).value ?? const [];
    final categoriesById = {
      for (final category in categories) category.id: category,
    };

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Archived habits'),
      ),
      body: archived.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No archived habits.'),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final habit = archived[index];
                final category = habit.categoryId == null
                    ? null
                    : categoriesById[habit.categoryId];
                return _ArchivedHabitTile(
                  habit: habit,
                  category: category,
                  onUnarchive: () => ref.read(habitsControllerProvider).unarchiveHabit(habit),
                  onTap: () => context.push(RoutePaths.habitDetail(habit.id)),
                );
              },
            ),
    );
  }
}

class _ArchivedHabitTile extends StatelessWidget {
  const _ArchivedHabitTile({
    required this.habit,
    required this.category,
    required this.onUnarchive,
    required this.onTap,
  });

  final Habit habit;
  final Category? category;
  final VoidCallback onUnarchive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = category == null
        ? colors.habits
        : Color(int.parse(category!.colorHex.replaceFirst('#', '0xFF')));
    final icon = category == null
        ? Icons.local_fire_department_rounded
        : resolveIcon(category!.icon);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(habit.name),
      subtitle: const Text('Archived'),
      trailing: TextButton(onPressed: onUnarchive, child: const Text('Unarchive')),
    );
  }
}
