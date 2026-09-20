import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CalendarLayout { month, agenda }

// Like Planner, retain the layout while navigating between app screens.
class CalendarLayoutController extends Notifier<CalendarLayout> {
  @override
  CalendarLayout build() => CalendarLayout.month;

  void select(CalendarLayout layout) => state = layout;
}

final calendarLayoutProvider =
    NotifierProvider<CalendarLayoutController, CalendarLayout>(
      CalendarLayoutController.new,
    );
