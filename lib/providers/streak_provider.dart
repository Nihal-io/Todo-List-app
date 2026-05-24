import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../shared/date_utils.dart';
import 'clock_provider.dart';
import 'tasks_provider.dart';

/// Streak summary for a single recurring task.
class TaskStreak {
  const TaskStreak({required this.current, required this.best});
  final int current;
  final int best;
}

/// Computes the current and best consecutive-completion streak for a
/// recurring task. The walk anchors on the latest *applicable* day that has
/// been marked complete — including future early completions — and walks
/// backward through every day the rule applies. This way ticking an
/// upcoming occurrence immediately bumps the streak badge without waiting
/// for the calendar date to arrive.
///
/// Non-recurring tasks return zero streaks.
final taskStreakProvider = Provider.family<TaskStreak, String>((ref, taskId) {
  final tasks = ref.watch(tasksListProvider);
  // Re-evaluate at the day boundary so the streak refreshes at midnight even
  // when no completion happens.
  ref.watch(todayProvider);

  Task? task;
  for (final t in tasks) {
    if (t.id == taskId) {
      task = t;
      break;
    }
  }
  if (task == null || !task.isRecurring) {
    return const TaskStreak(current: 0, best: 0);
  }

  final completed = <DateTime>{
    for (final d in task.completedDates) DateTime(d.year, d.month, d.day),
  };

  bool wasCompleted(DateTime d) => completed.any((c) => sameDay(c, d));

  // Anchor on the latest applicable day that has actually been ticked. If
  // the user completed Monday early on Saturday, the walk starts at Monday
  // and currentRun counts that completion immediately.
  DateTime? latestDone;
  for (final d in completed) {
    if (!task.recurrence!.appliesOn(d)) continue;
    if (latestDone == null || d.isAfter(latestDone)) latestDone = d;
  }
  if (latestDone == null) {
    return const TaskStreak(current: 0, best: 0);
  }

  int best = 0;
  int run = 0;
  int currentRun = 0;
  bool currentStreakActive = true;

  var cursor = latestDone;
  // Cap at ~2 years of history to keep the scan bounded for very old tasks.
  for (var i = 0; i < 730; i++) {
    if (!task.recurrence!.appliesOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    if (wasCompleted(cursor)) {
      run++;
      if (run > best) best = run;
      if (currentStreakActive) currentRun = run;
    } else {
      // Any miss between today and the most recent done day breaks the
      // current streak — only the longest run still counts toward `best`.
      currentStreakActive = false;
      run = 0;
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return TaskStreak(current: currentRun, best: best);
});
