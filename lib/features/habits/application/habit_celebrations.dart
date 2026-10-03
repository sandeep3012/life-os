import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/save_feedback.dart';

/// Streak lengths worth a beat of celebration — a week, a month, "it's a
/// habit now", and a full year.
const _streakMilestones = {7, 30, 100, 365};

/// Shows [showCelebration] when [newStreakDays] — the streak a check-in is
/// *about* to produce — lands exactly on one of [_streakMilestones].
///
/// Called with the predicted new streak (current + 1) rather than re-reading
/// it after the toggle: the check-in write and the stream that recomputes
/// [HabitProgress.streakDays] both go through the same Drift connection, so
/// re-reading immediately after would race the update rather than reliably
/// see it.
Future<void> celebrateStreakIfMilestone(
  BuildContext context,
  WidgetRef ref, {
  required String habitName,
  required int newStreakDays,
}) {
  if (!_streakMilestones.contains(newStreakDays)) return Future.value();
  return showCelebration(
    context,
    ref,
    title: '$newStreakDays-day streak!',
    message: '$habitName — keep it going.',
    emoji: '🔥',
  );
}
