import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../shared/date_utils.dart';
import 'clock_provider.dart';
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

DateTime _deadlineOf(Task t) => dateOnly(t.endDate ?? t.startDate);

bool _isPastDeadline(Task t, DateTime day) {
  if (t.isEvent || t.isRecurring) return false;
  return day.isAfter(_deadlineOf(t));
}

bool _isUpcomingFrom(Task t, DateTime today) {
  if (t.isRecurring) return t.nextOccurrenceAfter(today) != null;
  if (t.isEvent) {
    if (t.autoCompletedOn(today)) return false;
    return dateOnly(t.startDate).isAfter(dateOnly(today));
  }
  return dateOnly(t.startDate).isAfter(dateOnly(today));
}

/// Today's progress — actionable items active today (tasks only, not events).
final todayProgressProvider = Provider<TodayProgress>((ref) {
  final tasks = ref.watch(tasksListProvider);
  final t = ref.watch(todayProvider);
  final activeToday =
      tasks.where((x) => !x.isEvent && x.isActiveOn(t)).toList();
  final done = activeToday.where((x) => x.isCompletedOn(t)).length;
  return TodayProgress(done: done, total: activeToday.length);
});

final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksListProvider);
  final t = ref.watch(todayProvider);
  return tasks.where((x) => _isPastDeadline(x, t)).toList();
});

final currentTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksListProvider);
  final t = ref.watch(todayProvider);
  return tasks.where((x) => x.isActiveOn(t)).toList();
});

final upcomingTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksListProvider);
  final t = ref.watch(todayProvider);
  return tasks.where((x) => _isUpcomingFrom(x, t)).toList();
});
