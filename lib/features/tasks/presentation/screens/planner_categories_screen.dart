import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/app_database_provider.dart';
import '../../../finance/application/finance_providers.dart';
import '../../../finance/presentation/screens/category_management_screen.dart';
import '../../../habits/application/habits_providers.dart';
import '../../application/tasks_providers.dart';
import '../../data/planner_categories_repository.dart';

class PlannerCategoriesScreen extends ConsumerWidget {
  const PlannerCategoriesScreen({super.key, required this.kind})
    : assert(kind == 'task' || kind == 'habit');
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = kind == 'task'
        ? ref.watch(taskCategoriesProvider)
        : ref.watch(habitCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(kind == 'task' ? 'Task categories' : 'Habit categories'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not load categories.')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No categories yet. Add one below.'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final category = items[index];
                  return ListTile(
                    title: Text(category.name),
                    subtitle: const Text('Tap to edit'),
                    onTap: () => _edit(context, ref, category),
                    trailing: IconButton(
                      tooltip: 'Delete ${category.name}',
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: () => _delete(context, ref, category),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add category'),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Category? category,
  ) async {
    final result = await showCategoryEditorSheet(
      context,
      existing: category,
      fixedKind: kind,
    );
    if (result == null || !context.mounted) return;
    try {
      final controller = ref.read(financeControllerProvider);
      if (category == null) {
        await controller.addCategory(
          name: result.name,
          icon: result.icon,
          colorHex: result.colorHex,
          kind: kind,
        );
      } else {
        await controller.updateCategory(
          id: category.id,
          name: result.name,
          icon: result.icon,
          colorHex: result.colorHex,
          kind: kind,
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the category. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          'Delete “${category.name}”? Its ${kind == 'task' ? 'tasks' : 'habits'} will be kept without a category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await PlannerCategoriesRepository(
        ref.read(appDatabaseProvider),
      ).delete(category.id, kind);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete the category. Please try again.'),
          ),
        );
      }
    }
  }
}
