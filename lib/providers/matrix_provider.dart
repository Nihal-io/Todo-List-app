import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import 'clock_provider.dart';
import 'tasks_provider.dart';

/// Sentinel score used when a task has no foreseeable next occurrence.
/// Pushes such items to the bottom of their quadrant.
const int _matrixNoOccurrenceScore = 1 << 30;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// True when an event's end date has passed relative to [today].
///
/// Computed inline (rather than relying on [Task.hasAutoCompleted], which
/// reads `DateTime.now()` directly) so that the matrix is fully reactive
/// to the clock provider — including backward time movement, which causes
/// previously-ended events to reappear here.
bool _eventEnded(Task t, DateTime today) {
  if (!t.isEvent) return false;
  final e = _dateOnly(t.endDate ?? t.startDate);
  return today.isAfter(e);
}

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

/// Whether the task is currently open work that the matrix should display.
///
/// The matrix only shows pending work — completed items vanish on the next
/// panel revisit. Until then the screen layer keeps them visible via its
/// frozen-id snapshot so completion is a deliberate stroke-through, not a
/// disappearing trick under the user's finger.
bool isVisibleInMatrix(Task t, DateTime today) {
  final base = _dateOnly(today);
  if (t.isRecurring) {
    if (t.isCompletedOn(base)) return false;
    if (t.isActiveOn(base)) return true;
    return t.nextOccurrenceAfter(base) != null;
  }
  if (t.isEvent) {
    if (t.completed) return false;
    if (_eventEnded(t, base)) return false;
    return true;
  }
  return !t.completed;
}

/// Grouped, urgency-sorted view of open tasks for the matrix screen.
///
/// Watches both [tasksProvider] and [todayProvider] so the matrix
/// recomputes when the data changes *and* when the day rolls over.
final matrixItemsProvider = Provider<Map<MatrixQuadrant, List<Task>>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final today = ref.watch(todayProvider);

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

/// Bumped when the user returns to the Matrix tab from elsewhere. The
/// screen listens to this to drop its frozen snapshot, which purges
/// recently-completed tasks from view and re-applies urgency sort.
final matrixRevisitSignalProvider = StateProvider<int>((ref) => 0);
