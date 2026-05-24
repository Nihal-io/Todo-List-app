import '../../models/task.dart';

DateTime homeDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime homeDeadlineOf(Task t) {
  final d = t.endDate ?? t.startDate;
  return DateTime(d.year, d.month, d.day);
}

/// Display tiers (in order):
/// 0 — active tasks (sorted by matrix)
/// 1 — active events, grouped together (sorted by matrix, then date)
/// 2 — completed tasks + events (always below the events block)
int _homeTier(Task t, bool Function(Task) isDone) {
  if (isDone(t)) return 2;
  if (t.isEvent) return 1;
  return 0;
}

int compareHomeTasks(
  Task a,
  Task b, {
  required bool Function(Task) isDone,
  int Function(Task, Task)? tieBreak,
}) {
  final ta = _homeTier(a, isDone);
  final tb = _homeTier(b, isDone);
  if (ta != tb) return ta.compareTo(tb);

  final q = a.quadrant.index.compareTo(b.quadrant.index);
  if (q != 0) return q;

  if (tieBreak != null) return tieBreak(a, b);
  return b.priority.index.compareTo(a.priority.index);
}

int compareCurrentTasks(Task a, Task b, DateTime today) =>
    compareHomeTasks(
      a,
      b,
      isDone: (t) => t.isCompletedOn(today),
      tieBreak: (x, y) => _tieBreakByKind(x, y, today),
    );

int compareUpcomingTasks(Task a, Task b, DateTime today) =>
    compareHomeTasks(
      a,
      b,
      isDone: (t) => t.isRowDoneOnDate(today, inUpcomingSection: true),
      tieBreak: (x, y) => _tieBreakByKind(x, y, today),
    );

int _tieBreakByKind(Task x, Task y, DateTime today) {
  if (x.isEvent && y.isEvent) {
    return homeDateOnly(x.startDate).compareTo(homeDateOnly(y.startDate));
  }
  if (!x.isEvent && !y.isEvent) {
    final aDate = x.nextOccurrenceAfter(today) ?? homeDateOnly(x.startDate);
    final bDate = y.nextOccurrenceAfter(today) ?? homeDateOnly(y.startDate);
    final cmp = aDate.compareTo(bDate);
    if (cmp != 0) return cmp;
  }
  return y.priority.index.compareTo(x.priority.index);
}

int compareOverdueTasks(Task a, Task b) => compareHomeTasks(
      a,
      b,
      isDone: (t) => t.completed,
      tieBreak: (x, y) =>
          homeDeadlineOf(y).compareTo(homeDeadlineOf(x)),
    );

/// When [sortEnabled], applies [comparator]. Otherwise preserves [frozenIds]
/// so completion toggles do not jump rows until the user revisits the panel.
List<Task> applyHomeDisplayOrder({
  required List<Task> tasks,
  required bool sortEnabled,
  required List<String>? frozenIds,
  required int Function(Task, Task) comparator,
}) {
  if (sortEnabled || frozenIds == null) {
    final sorted = [...tasks]..sort(comparator);
    return sorted;
  }

  final byId = {for (final t in tasks) t.id: t};
  final ordered = <Task>[];
  for (final id in frozenIds) {
    final task = byId.remove(id);
    if (task != null) ordered.add(task);
  }
  ordered.addAll(byId.values);
  return ordered;
}
