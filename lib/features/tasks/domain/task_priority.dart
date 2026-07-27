enum TaskPriority { high, medium, low }

extension TaskPriorityX on TaskPriority {
  String get value => name;

  static TaskPriority fromValue(String value) {
    return TaskPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => TaskPriority.medium,
    );
  }

  String get label => switch (this) {
    TaskPriority.high => 'HIGH',
    TaskPriority.medium => 'MED',
    TaskPriority.low => 'LOW',
  };
}
