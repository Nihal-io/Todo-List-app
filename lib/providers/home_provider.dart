import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'tasks_provider.dart';

/// Bumped when user leaves Home and navigates back to Home.
/// Home screen listens to this to apply deferred resorting.
final homeRevisitSignalProvider = StateProvider<int>((ref) => 0);

/// Aggregated counts used by the Home dashboard's progress card.
class TodayProgress {
  const TodayProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
  int get percent => (fraction * 100).round();
}

DateTime _todayDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime _deadlineOf(Task t) {
  final d = t.endDate ?? t.startDate;
  return DateTime(d.year, d.month, d.day);
}

bool _isPastDeadline(Task t, DateTime day) {
  if (t.isEvent || t.isRecurring) return false;
  return day.isAfter(_deadlineOf(t));
}

bool _isUpcomingFrom(Task t, DateTime today) {
  if (t.isRecurring) return t.nextOccurrenceAfter(today) != null;
  if (t.isEvent) {
    if (t.hasAutoCompleted) return false;
    return _dateOnly(t.startDate).isAfter(_dateOnly(today));
  }
  return _dateOnly(t.startDate).isAfter(_dateOnly(today));
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Today's progress — actionable items active today (tasks only, not events).
final todayProgressProvider = Provider<TodayProgress>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  final activeToday =
      tasks.where((t) => !t.isEvent && t.isActiveOn(today)).toList();
  final done =
      activeToday.where((t) => t.isCompletedOn(today)).length;
  return TodayProgress(done: done, total: activeToday.length);
});

/// Tasks whose deadline has passed.
/// Events and recurring tasks never appear here.
/// Completed items stay visible so tapping does not make them "disappear".
/// Sorting is handled in the Home UI to allow deferred reordering.
final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  return tasks.where((t) => _isPastDeadline(t, today)).toList();
});

/// All items active today — tasks and events. Completed ones stay visible.
/// Sorting is handled in the Home UI to allow deferred reordering.
final currentTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  return tasks.where((t) => t.isActiveOn(today)).toList();
});

/// Tasks with a future date: non-recurring with start after today, recurring
/// with a next occurrence after today, future events.
/// Completed items remain visible in this tab to avoid "deleted" behavior.
/// Sorting is handled in the Home UI to allow deferred reordering.
final upcomingTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  return tasks.where((t) => _isUpcomingFrom(t, today)).toList();
});
