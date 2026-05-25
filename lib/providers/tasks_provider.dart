import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/sub_task.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/task_repository.dart';
import '../shared/date_utils.dart';

const _uuid = Uuid();

/// Outcome of attempting to toggle a task's completion state.
enum TaskToggleResult {
  completed,
  uncompleted,
  blockedSubtasks,
  unchanged,
}

/// Outcome of toggling a subtask, including any parent sync.
class SubtaskToggleResult {
  const SubtaskToggleResult({
    this.parentAutoCompleted = false,
    this.parentAutoUncompleted = false,
  });

  final bool parentAutoCompleted;
  final bool parentAutoUncompleted;
}

// ---------------------------------------------------------------------------
// Sample data — used the first time the app boots (no persisted file yet).
// ---------------------------------------------------------------------------

List<Task> buildSampleTasks() {
  final today_ = today();
  final endOfNextMonth = DateTime(today_.year, today_.month + 2, 0);

  // Recurring sample-task history. Walks back 60 days from today and ticks
  // every applicable day except the ones in `skipNthOccurrences`, so the
  // analytics charts look populated on first launch.
  Set<DateTime> seedHistory({
    required WeeklyRecurrence rule,
    required DateTime start,
    required DateTime end,
    required Set<int> skipNthOccurrences,
  }) {
    final out = <DateTime>{};
    var n = 0;
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      if (!rule.appliesOn(d)) continue;
      n++;
      if (!skipNthOccurrences.contains(n)) {
        out.add(DateTime(d.year, d.month, d.day));
      }
    }
    return out;
  }

  final gymStart = today_.subtract(const Duration(days: 60));
  const gymRule = WeeklyRecurrence(
    weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
  );
  // Gym is "done for the day" only on these past Mon/Wed/Fri dates.
  // The misses overlap with Standup misses on different days, so the
  // overall chart shows a mix of 0% / 50% / 100% bars.
  final gymDone = seedHistory(
    rule: gymRule,
    start: gymStart,
    end: today_.subtract(const Duration(days: 1)),
    skipNthOccurrences: const {9, 10, 18, 23},
  );

  // Standup runs every weekday and overlaps Gym on Mon/Wed/Fri. A different
  // miss pattern means some Gym/Standup days end up at 50% completion.
  final standupStart = today_.subtract(const Duration(days: 60));
  const standupRule = WeeklyRecurrence(
    weekdays: {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
  );
  final standupDone = seedHistory(
    rule: standupRule,
    start: standupStart,
    end: today_.subtract(const Duration(days: 1)),
    skipNthOccurrences: const {4, 5, 12, 19, 27, 33},
  );

  final yogaStart = today_.subtract(const Duration(days: 60));
  final yogaRule = WeeklyRecurrence(
    weekdays: const {DateTime.tuesday, DateTime.thursday},
    until: endOfNextMonth,
  );
  final yogaDone = seedHistory(
    rule: yogaRule,
    start: yogaStart,
    end: today_.subtract(const Duration(days: 1)),
    skipNthOccurrences: const {3, 7, 8, 14},
  );

  // Journal runs every single day so it's always one of the contributors.
  // Combined with Gym/Standup/Read/Yoga, days end up with 1..4 applicable
  // recurring tasks — and with distinct miss patterns the chart hits the
  // full 25 / 33 / 50 / 66 / 75 / 100 % spectrum.
  final journalStart = today_.subtract(const Duration(days: 60));
  const journalRule = WeeklyRecurrence(weekdays: {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  });
  final journalDone = seedHistory(
    rule: journalRule,
    start: journalStart,
    end: today_.subtract(const Duration(days: 1)),
    skipNthOccurrences: const {6, 13, 20, 28, 35, 42, 51},
  );

  // Read shares Gym's Mon/Wed/Fri rhythm; together with Gym + Standup +
  // Journal that puts four tasks on Mon/Wed/Fri, so 25% (1/4), 50%, 75%
  // and 100% all become reachable on those days.
  final readStart = today_.subtract(const Duration(days: 60));
  const readRule = WeeklyRecurrence(weekdays: {
    DateTime.monday,
    DateTime.wednesday,
    DateTime.friday,
  });
  final readDone = seedHistory(
    rule: readRule,
    start: readStart,
    end: today_.subtract(const Duration(days: 1)),
    skipNthOccurrences: const {2, 8, 14, 17, 25},
  );

  return [
    Task(
      id: _uuid.v4(),
      title: 'Submit assignment',
      startDate: today_,
      priority: TaskPriority.high,
      quadrant: MatrixQuadrant.doFirst,
      notes: 'Double-check the references section before uploading.',
      subtasks: [
        SubTask(id: _uuid.v4(), title: 'Finalize draft'),
        SubTask(id: _uuid.v4(), title: 'Run plagiarism check'),
        SubTask(id: _uuid.v4(), title: 'Upload PDF'),
      ],
    ),
    Task(
      id: _uuid.v4(),
      title: 'Prepare presentation',
      startDate: today_.add(const Duration(days: 2)),
      priority: TaskPriority.high,
      quadrant: MatrixQuadrant.doFirst,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Exams',
      startDate: today_.subtract(const Duration(days: 1)),
      endDate: today_.add(const Duration(days: 3)),
      kind: TaskKind.event,
      quadrant: MatrixQuadrant.doFirst,
      startTime: const TaskTime(hour: 9, minute: 0),
      endTime: const TaskTime(hour: 12, minute: 0),
    ),
    Task(
      id: _uuid.v4(),
      title: 'Read chapter 4',
      startDate: today_,
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.schedule,
      completed: true,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Write report',
      startDate: today_.add(const Duration(days: 1)),
      endDate: today_.add(const Duration(days: 3)),
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.schedule,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Hackathon',
      startDate: today_.add(const Duration(days: 6)),
      endDate: today_.add(const Duration(days: 8)),
      kind: TaskKind.event,
      quadrant: MatrixQuadrant.schedule,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Gym',
      startDate: gymStart,
      recurrence: gymRule,
      completedDates: gymDone,
      // One subtask pre-checked so today's overall bar shows partial credit
      // even before the user touches anything — demonstrates the subtask
      // weighting on the analytics chart.
      subtasks: [
        SubTask(id: _uuid.v4(), title: 'Warm up', completed: true),
        SubTask(id: _uuid.v4(), title: 'Workout'),
        SubTask(id: _uuid.v4(), title: 'Cool down'),
      ],
      priority: TaskPriority.low,
      quadrant: MatrixQuadrant.delegate,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Standup',
      startDate: standupStart,
      recurrence: standupRule,
      completedDates: standupDone,
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.delegate,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Journal',
      startDate: journalStart,
      recurrence: journalRule,
      completedDates: journalDone,
      priority: TaskPriority.low,
      quadrant: MatrixQuadrant.schedule,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Read',
      startDate: readStart,
      recurrence: readRule,
      completedDates: readDone,
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.schedule,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Reply to emails',
      startDate: today_.subtract(const Duration(days: 2)),
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.delegate,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Yoga',
      startDate: yogaStart,
      recurrence: yogaRule,
      completedDates: yogaDone,
      priority: TaskPriority.low,
      quadrant: MatrixQuadrant.eliminate,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) => TaskRepository());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Convenience to override [notificationServiceProvider] with a pre-built,
/// already-initialised instance from `main()`.
Override notificationServiceProviderOverride(NotificationService instance) =>
    notificationServiceProvider.overrideWithValue(instance);

/// Whether local notifications are enabled. Persisted via SharedPreferences
/// (see [settingsProvider]).
final notificationsEnabledProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Tasks notifier — async load/save, in-memory CRUD
// ---------------------------------------------------------------------------

class TasksNotifier extends AsyncNotifier<List<Task>> {
  late TaskRepository _repo;
  late NotificationService _notifications;

  @override
  Future<List<Task>> build() async {
    _repo = ref.watch(taskRepositoryProvider);
    _notifications = ref.watch(notificationServiceProvider);
    _notifications.onTaskReminderFired = _onTaskReminderFired;
    final loaded = await _repo.load();
    if (loaded == null) {
      final samples = buildSampleTasks();
      unawaited(_repo.save(samples));
      _rescheduleAll(samples);
      unawaited(_syncForeground(samples));
      return samples;
    }
    _rescheduleAll(loaded);
    unawaited(_syncForeground(loaded));
    return loaded;
  }

  List<Task> get _current => state.valueOrNull ?? const <Task>[];

  Future<void> _commit(List<Task> next) async {
    state = AsyncData(next);
    await _repo.save(next);
    unawaited(_syncForeground(next));
  }

  Future<void> _syncForeground(List<Task> tasks) async {
    if (!_notificationsEnabled) {
      await _notifications.stopTodayForeground();
      return;
    }
    await _notifications.updateTodayForeground(tasks);
  }

  void _onTaskReminderFired(String taskId) {
    if (!_notificationsEnabled) return;
    Task? task;
    for (final t in _current) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) return;
    unawaited(_notifications.scheduleForTask(task, enabled: true));
    unawaited(_syncForeground(_current));
  }

  /// Rebuilds scheduled alarms and the foreground summary — e.g. on app resume.
  Future<void> refreshNotifications() async {
    if (!_notificationsEnabled) {
      await _notifications.stopTodayForeground();
      return;
    }
    _rescheduleAll(_current);
    await _syncForeground(_current);
  }

  bool get _notificationsEnabled =>
      ref.read(notificationsEnabledProvider);

  void _rescheduleAll(List<Task> tasks) {
    if (!_notificationsEnabled) return;
    unawaited(_notifications.scheduleRemindersForAll(tasks, enabled: true));
  }

  /// Replace all tasks with the canonical sample set.
  Future<void> reseed() async {
    await _notifications.cancelAll();
    final next = buildSampleTasks();
    await _commit(next);
    _rescheduleAll(next);
  }

  Future<void> add(Task task) async {
    final next = [..._current, task];
    await _commit(next);
    _rescheduleAll(next);
  }

  /// Removes the task and returns it so the caller (e.g. an "Undo" SnackBar)
  /// can restore it later.
  Future<Task?> remove(String id) async {
    Task? removed;
    final next = <Task>[];
    for (final t in _current) {
      if (t.id == id) {
        removed = t;
      } else {
        next.add(t);
      }
    }
    if (removed == null) return null;
    await _commit(next);
    _rescheduleAll(next);
    return removed;
  }

  /// Restores a previously-removed task (used by Undo).
  Future<void> restore(Task task) async {
    if (_current.any((t) => t.id == task.id)) return;
    final next = [..._current, task];
    await _commit(next);
    _rescheduleAll(next);
  }

  /// Toggle for non-recurring tasks and events (flips the single `completed`
  /// bool). For recurring tasks, use [toggleForDay].
  ///
  /// Completing is blocked while any subtask remains unchecked.
  Future<TaskToggleResult> toggle(String id) async {
    Task? target;
    for (final t in _current) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    if (target == null || target.isRecurring) {
      return TaskToggleResult.unchanged;
    }

    final completing = !target.completed;
    if (completing && !target.allSubtasksComplete) {
      return TaskToggleResult.blockedSubtasks;
    }

    final next = <Task>[];
    for (final t in _current) {
      if (t.id == id) {
        next.add(t.copyWith(completed: completing));
      } else {
        next.add(t);
      }
    }
    await _commit(next);
    _rescheduleAll(next);
    return completing
        ? TaskToggleResult.completed
        : TaskToggleResult.uncompleted;
  }

  /// Toggle completion for a specific day. Recurring tasks add/remove the day
  /// from `completedDates`. Non-recurring tasks and events flip `completed`.
  ///
  /// Completing is blocked while any subtask remains unchecked.
  ///
  /// For recurring tasks, completing on a day the recurrence doesn't apply
  /// to (e.g. an early tick from the grid or detail sheet on an off-day)
  /// snaps to the next applicable occurrence so the streak provider and
  /// analytics actually count it.
  Future<TaskToggleResult> toggleForDay(String id, DateTime day) async {
    Task? target;
    for (final t in _current) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    if (target == null) return TaskToggleResult.unchanged;

    final d = _effectiveActionDay(target, day);
    final completing = !target.isCompletedOn(d);
    if (completing && !target.allSubtasksComplete) {
      return TaskToggleResult.blockedSubtasks;
    }

    final next = <Task>[];
    for (final t in _current) {
      if (t.id != id) {
        next.add(t);
        continue;
      }
      if (t.isRecurring) {
        final newSet = {...t.completedDates};
        final existing = newSet
            .where((x) =>
                x.year == d.year && x.month == d.month && x.day == d.day)
            .toList();
        if (existing.isEmpty) {
          newSet.add(d);
        } else {
          newSet.removeAll(existing);
        }
        next.add(t.copyWith(completedDates: newSet));
      } else {
        next.add(t.copyWith(completed: completing));
      }
    }
    await _commit(next);
    _rescheduleAll(next);
    return completing
        ? TaskToggleResult.completed
        : TaskToggleResult.uncompleted;
  }

  /// Snaps a calendar day to a date that the streak/analytics layer will
  /// actually count: for recurring tasks ticked on a non-applicable day,
  /// pushes the tick forward to the next occurrence the rule applies to.
  /// No-op for non-recurring tasks or days already on the rule.
  DateTime _effectiveActionDay(Task task, DateTime day) {
    final d = dateOnly(day);
    if (!task.isRecurring) return d;
    if (task.recurrence!.appliesOn(d)) return d;
    final snapped = task.nextOccurrenceAfter(d);
    return snapped == null ? d : dateOnly(snapped);
  }

  Future<void> updateTask(Task task) async {
    final next = [
      for (final t in _current) (t.id == task.id ? task : t),
    ];
    await _commit(next);
    _rescheduleAll(next);
  }

  /// Toggles a single subtask's completed state on its parent and keeps the
  /// parent completion in sync (auto-complete when all subtasks are done;
  /// uncomplete when any subtask is unchecked).
  Future<SubtaskToggleResult> toggleSubtask(
    String taskId,
    String subtaskId, {
    DateTime? actionDay,
  }) async {
    Task? original;
    for (final t in _current) {
      if (t.id == taskId) {
        original = t;
        break;
      }
    }
    if (original == null) return const SubtaskToggleResult();

    final day = actionDay != null ? dateOnly(actionDay) : null;
    final wasParentDone = original.isRecurring
        ? (day != null && original.isCompletedOn(day))
        : original.completed;

    var updated = original.copyWith(
      subtasks: [
        for (final s in original.subtasks)
          if (s.id == subtaskId)
            s.copyWith(completed: !s.completed)
          else
            s,
      ],
    );

    var parentAutoCompleted = false;
    var parentAutoUncompleted = false;

    if (updated.allSubtasksComplete && !wasParentDone) {
      updated = _setParentCompleted(updated, day, true);
      parentAutoCompleted = true;
    } else if (!updated.allSubtasksComplete && wasParentDone) {
      updated = _setParentCompleted(updated, day, false);
      parentAutoUncompleted = true;
    }

    final next = [
      for (final t in _current) (t.id == taskId ? updated : t),
    ];
    await _commit(next);
    _rescheduleAll(next);
    return SubtaskToggleResult(
      parentAutoCompleted: parentAutoCompleted,
      parentAutoUncompleted: parentAutoUncompleted,
    );
  }

  /// Marks every subtask complete or incomplete. When completing all, the
  /// parent is auto-completed for [actionDay]; when clearing all, the parent
  /// is auto-uncompleted.
  Future<SubtaskToggleResult> toggleAllSubtasks(
    String taskId, {
    DateTime? actionDay,
  }) async {
    Task? original;
    for (final t in _current) {
      if (t.id == taskId) {
        original = t;
        break;
      }
    }
    if (original == null || !original.hasSubtasks) {
      return const SubtaskToggleResult();
    }

    final day = actionDay != null ? dateOnly(actionDay) : null;
    final wasParentDone = original.isRecurring
        ? (day != null && original.isCompletedOn(day))
        : original.completed;
    final completeAll = !original.allSubtasksComplete;

    var updated = original.copyWith(
      subtasks: [
        for (final s in original.subtasks) s.copyWith(completed: completeAll),
      ],
    );

    var parentAutoCompleted = false;
    var parentAutoUncompleted = false;

    if (completeAll && !wasParentDone) {
      updated = _setParentCompleted(updated, day, true);
      parentAutoCompleted = true;
    } else if (!completeAll && wasParentDone) {
      updated = _setParentCompleted(updated, day, false);
      parentAutoUncompleted = true;
    }

    final next = [
      for (final t in _current) (t.id == taskId ? updated : t),
    ];
    await _commit(next);
    _rescheduleAll(next);
    return SubtaskToggleResult(
      parentAutoCompleted: parentAutoCompleted,
      parentAutoUncompleted: parentAutoUncompleted,
    );
  }

  Task _setParentCompleted(Task task, DateTime? day, bool complete) {
    if (task.isRecurring) {
      if (day == null) return task;
      final d = _effectiveActionDay(task, day);
      final newSet = {...task.completedDates};
      final existing = newSet
          .where((x) => x.year == d.year && x.month == d.month && x.day == d.day)
          .toList();
      if (complete) {
        if (existing.isEmpty) newSet.add(d);
      } else {
        newSet.removeAll(existing);
      }
      return task.copyWith(completedDates: newSet);
    }
    return task.copyWith(completed: complete);
  }

  // ---------------- Bulk operations (multi-select) ----------------

  Future<void> bulkComplete(Set<String> ids, DateTime onDay) async {
    final next = <Task>[];
    for (final t in _current) {
      if (!ids.contains(t.id)) {
        next.add(t);
        continue;
      }

      // Cascade-complete any open subtasks so bulk doesn't silently skip
      // tasks whose checklists aren't ticked off — matches what the detail
      // sheet's Complete button does for an individual task.
      var updated = t;
      if (updated.hasSubtasks && !updated.allSubtasksComplete) {
        updated = updated.copyWith(
          subtasks: [
            for (final s in updated.subtasks) s.copyWith(completed: true),
          ],
        );
      }

      if (updated.isRecurring) {
        // Snap non-applicable days (e.g. bulk-complete on a Sunday for a
        // Mon/Wed/Fri task) to the next applicable occurrence so the tick
        // is visible to the streak and analytics layers.
        final d = _effectiveActionDay(updated, onDay);
        if (updated.completedDates.any((x) => sameDay(x, d))) {
          next.add(updated);
        } else {
          next.add(updated
              .copyWith(completedDates: {...updated.completedDates, d}));
        }
      } else {
        next.add(updated.copyWith(completed: true));
      }
    }
    await _commit(next);
    _rescheduleAll(next);
  }

  Future<List<Task>> bulkDelete(Set<String> ids) async {
    final removed = <Task>[];
    final next = <Task>[];
    for (final t in _current) {
      if (ids.contains(t.id)) {
        removed.add(t);
      } else {
        next.add(t);
      }
    }
    await _commit(next);
    _rescheduleAll(next);
    return removed;
  }

  Future<void> bulkMoveQuadrant(Set<String> ids, MatrixQuadrant q) async {
    final next = [
      for (final t in _current)
        if (ids.contains(t.id)) t.copyWith(quadrant: q) else t,
    ];
    await _commit(next);
  }

  // ---------------- Drag-to-reorder ----------------

  /// Reorders the visible items so that [orderedIds] are produced in that
  /// order. Tasks not in [orderedIds] keep their existing relative order
  /// and end up after the reordered prefix.
  ///
  /// Implementation: rewrite `sortIndex` for the listed ids using a
  /// monotonically increasing series so the home sort respects the new order.
  Future<void> reorder(List<String> orderedIds) async {
    if (orderedIds.isEmpty) return;
    final base = DateTime.now().microsecondsSinceEpoch.toDouble();
    final byId = {for (final t in _current) t.id: t};
    var i = 0;
    for (final id in orderedIds) {
      final t = byId[id];
      if (t == null) continue;
      byId[id] = t.copyWith(sortIndex: base + i);
      i++;
    }
    await _commit(byId.values.toList());
  }

  /// Toggle notifications on/off and re-schedule everything appropriately.
  Future<void> applyNotificationsEnabled(bool enabled) async {
    if (enabled) {
      await _notifications.scheduleRemindersForAll(_current, enabled: true);
      await _syncForeground(_current);
    } else {
      await _notifications.cancelAll();
      await _notifications.stopTodayForeground();
    }
  }
}

final tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

/// Synchronous view of the tasks list. While the initial load is in flight
/// this returns an empty list, which is fine for downstream filtering.
final tasksListProvider = Provider<List<Task>>((ref) {
  return ref.watch(tasksProvider).valueOrNull ?? const <Task>[];
});

/// All tasks active on the given [day].
final tasksForDayProvider = Provider.family<List<Task>, DateTime>((ref, day) {
  final tasks = ref.watch(tasksListProvider);
  return tasks.where((t) => t.isActiveOn(day)).toList();
});
