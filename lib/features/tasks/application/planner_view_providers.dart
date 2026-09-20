import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TaskLayout { list, priorities }

enum HabitLayout { categories, completion }

// Keep each choice when moving between Planner tabs and routes.
class TaskLayoutController extends Notifier<TaskLayout> {
  @override
  TaskLayout build() => TaskLayout.list;
  void select(TaskLayout value) => state = value;
}

class HabitLayoutController extends Notifier<HabitLayout> {
  @override
  HabitLayout build() => HabitLayout.categories;
  void select(HabitLayout value) => state = value;
}

final taskLayoutProvider = NotifierProvider<TaskLayoutController, TaskLayout>(
  TaskLayoutController.new,
);
final habitLayoutProvider =
    NotifierProvider<HabitLayoutController, HabitLayout>(
      HabitLayoutController.new,
    );
