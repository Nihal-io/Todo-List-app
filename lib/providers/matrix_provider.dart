import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../shared/date_utils.dart' as date_utils;
import 'clock_provider.dart';
import 'settings_provider.dart';
import 'tasks_provider.dart';

/// Sentinel score used when a task has no foreseeable next occurrence.
/// Pushes such items to the bottom of their quadrant.
const int _matrixNoOccurrenceScore = 1 << 30;

DateTime _dateOnly(DateTime d) => date_utils.dateOnly(d);

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

/// Whether the task is currently open work that the grid view should display.
///
/// Completed items vanish on the next panel revisit. The screen layer keeps
/// them visible via its frozen-id snapshot until then.
bool isVisibleInGrid(Task t, DateTime today, {required bool includeEvents}) {
  if (t.isEvent && !includeEvents) return false;
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

/// Grouped, urgency-sorted view of open tasks for the grid view screen.
final matrixItemsProvider = Provider<Map<MatrixQuadrant, List<Task>>>((ref) {
  final tasks = ref.watch(tasksListProvider);
  final today = ref.watch(todayProvider);
  final settings = ref.watch(resolvedSettingsProvider);
  final includeEvents = settings.showGridEvents;

  final grouped = <MatrixQuadrant, List<Task>>{
    for (final q in MatrixQuadrant.values) q: <Task>[],
  };

  for (final t in tasks) {
    if (isVisibleInGrid(t, today, includeEvents: includeEvents)) {
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

/// Bumped when the user returns to the Grid View tab from elsewhere. The
/// screen listens to this to drop its frozen snapshot, which purges
/// recently-completed tasks from view and re-applies urgency sort.
final matrixRevisitSignalProvider = StateProvider<int>((ref) => 0);

/// Total open items across all quadrants.
final gridOpenCountProvider = Provider<int>((ref) {
  final items = ref.watch(matrixItemsProvider);
  return items.values.fold(0, (sum, list) => sum + list.length);
});

/// Open items whose urgency score is negative (overdue / past start).
final gridOverdueCountProvider = Provider<int>((ref) {
  final items = ref.watch(matrixItemsProvider);
  final today = ref.watch(todayProvider);
  var count = 0;
  for (final list in items.values) {
    for (final t in list) {
      if (matrixUrgencyScore(t, today) < 0) count++;
    }
  }
  return count;
});
