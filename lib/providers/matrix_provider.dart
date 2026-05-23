import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'tasks_provider.dart';

/// Sentinel score used when a task has no foreseeable next occurrence.
/// Pushes such items to the bottom of their quadrant.
const int _matrixNoOccurrenceScore = 1 << 30;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _todayDate() => _dateOnly(DateTime.now());

/// Urgency score for matrix sorting.
///
/// Lower = more urgent. Negative = overdue / event already in progress.
/// Returns [_matrixNoOccurrenceScore] for recurring tasks with no upcoming
/// occurrence in the search horizon.
int matrixUrgencyScore(Task t, DateTime today) {
  final base = _dateOnly(today);
  if (t.isRecurring) {
    if (t.isActiveOn(base)) return 0;
    final next = t.nextOccurrenceAfter(base);
    if (next == null) return _matrixNoOccurrenceScore;
    return _dateOnly(next).difference(base).inDays;
  }
  if (t.isEvent) {
    final s = _dateOnly(t.startDate);
    return s.difference(base).inDays;
  }
  final d = t.endDate ?? t.startDate;
  return _dateOnly(d).difference(base).inDays;
}

/// Whether the task is open work that the matrix should display.
///
/// Completed items, auto-completed events, and recurring tasks with no
/// future occurrence are hidden — the matrix is a decision surface for
/// pending work only.
bool isVisibleInMatrix(Task t, DateTime today) {
  final base = _dateOnly(today);
  if (t.isRecurring) {
    if (t.isCompletedOn(base)) return false;
    if (t.isActiveOn(base)) return true;
    return t.nextOccurrenceAfter(base) != null;
  }
  if (t.isEvent) {
    if (t.completed) return false;
    if (t.hasAutoCompleted) return false;
    return true;
  }
  return !t.completed;
}

/// Grouped, urgency-sorted view of open tasks for the matrix screen.
///
/// Recomputes whenever [tasksProvider] changes. Within each quadrant items
/// are sorted ascending by [matrixUrgencyScore] so the most urgent work
/// floats to the top.
final matrixItemsProvider = Provider<Map<MatrixQuadrant, List<Task>>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = _todayDate();

  final grouped = <MatrixQuadrant, List<Task>>{
    for (final q in MatrixQuadrant.values) q: <Task>[],
  };

  for (final t in tasks) {
    if (isVisibleInMatrix(t, today)) {
      grouped[t.quadrant]!.add(t);
    }
  }

  for (final q in MatrixQuadrant.values) {
    grouped[q]!.sort((a, b) {
      final sa = matrixUrgencyScore(a, today);
      final sb = matrixUrgencyScore(b, today);
      final cmp = sa.compareTo(sb);
      if (cmp != 0) return cmp;
      final pCmp = b.priority.index.compareTo(a.priority.index);
      if (pCmp != 0) return pCmp;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
  }

  return grouped;
});
