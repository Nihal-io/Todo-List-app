import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'tasks_provider.dart';

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

/// Deadline used for overdue calculations: a multi-day task is considered
/// overdue once its [endDate] is past; a single-day task once its [startDate]
/// is past.
DateTime _deadlineOf(Task t) {
  final d = t.endDate ?? t.startDate;
  return DateTime(d.year, d.month, d.day);
}

DateTime _startDateOnly(Task t) =>
    DateTime(t.startDate.year, t.startDate.month, t.startDate.day);

/// Today's progress — number of tasks active today that are completed
/// vs. the total active today.
final todayProgressProvider = Provider<TodayProgress>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  final activeToday = tasks.where((t) => t.occursOn(today)).toList();
  final done = activeToday.where((t) => t.completed).length;
  return TodayProgress(done: done, total: activeToday.length);
});

/// Incomplete tasks whose deadline has passed.
/// Sorted by deadline descending (most recently overdue first).
final overdueTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  final list = tasks
      .where((t) => !t.completed && _deadlineOf(t).isBefore(today))
      .toList()
    ..sort((a, b) => _deadlineOf(b).compareTo(_deadlineOf(a)));
  return list;
});

/// Incomplete tasks active today.
/// Sorted high → medium → low priority.
final currentTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  final list = tasks
      .where((t) => !t.completed && t.occursOn(today))
      .toList()
    ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  return list;
});

/// Incomplete tasks whose [startDate] is strictly after today.
/// Sorted high → medium → low priority (importance, not date).
final upcomingTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();
  final list = tasks
      .where((t) => !t.completed && _startDateOnly(t).isAfter(today))
      .toList()
    ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  return list;
});
