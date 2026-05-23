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
/// recurring task, walking backwards from today through every day the
/// rule applied. Non-recurring tasks return zero streaks.
final taskStreakProvider = Provider.family<TaskStreak, String>((ref, taskId) {
  final tasks = ref.watch(tasksListProvider);
  final today = ref.watch(todayProvider);
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

  int current = 0;
  int best = 0;
  int run = 0;

  var cursor = today;
  // Walk back up to ~2 years to cap the work.
  for (var i = 0; i < 730; i++) {
    if (!task.recurrence!.appliesOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      continue;
    }
    if (wasCompleted(cursor)) {
      run++;
      if (run > best) best = run;
      if (i == 0 ||
          (i > 0 && current == i) ||
          (current == run - 1)) {
        // current is the run ending at "today" if today applies and is done,
        // or the most recent run ending on the closest applicable day.
      }
    } else {
      // First miss after today ends the current streak.
      if (current == 0) current = run;
      run = 0;
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }
  if (current == 0) current = run;
  if (run > best) best = run;
  return TaskStreak(current: current, best: best);
});
