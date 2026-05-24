import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/sub_task.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/task_repository.dart';
import '../shared/date_utils.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Sample data — used the first time the app boots (no persisted file yet).
// ---------------------------------------------------------------------------

List<Task> buildSampleTasks() {
  final today_ = today();
  final endOfNextMonth = DateTime(today_.year, today_.month + 2, 0);

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
      startDate: today_,
      recurrence: const WeeklyRecurrence(
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      ),
      priority: TaskPriority.low,
      quadrant: MatrixQuadrant.delegate,
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
      startDate: today_,
      recurrence: WeeklyRecurrence(
        weekdays: const {DateTime.tuesday, DateTime.thursday},
        until: endOfNextMonth,
      ),
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
  Future<void> toggle(String id) async {
    final next = <Task>[];
    Task? updated;
    for (final t in _current) {
      if (t.id == id && !t.isRecurring) {
        updated = t.copyWith(completed: !t.completed);
        next.add(updated);
      } else {
        next.add(t);
      }
    }
    await _commit(next);
    _rescheduleAll(next);
  }

  /// Toggle completion for a specific day. Recurring tasks add/remove the day
  /// from `completedDates`. Non-recurring tasks and events flip `completed`.
  Future<void> toggleForDay(String id, DateTime day) async {
    final next = <Task>[];
    Task? updated;
    for (final t in _current) {
      if (t.id != id) {
        next.add(t);
        continue;
      }
      if (t.isRecurring) {
        final d = dateOnly(day);
        final newSet = {...t.completedDates};
        final existing = newSet
            .where((x) => x.year == d.year && x.month == d.month && x.day == d.day)
            .toList();
        if (existing.isEmpty) {
          newSet.add(d);
        } else {
          newSet.removeAll(existing);
        }
        updated = t.copyWith(completedDates: newSet);
      } else {
        updated = t.copyWith(completed: !t.completed);
      }
      next.add(updated);
    }
    await _commit(next);
    _rescheduleAll(next);
  }

  Future<void> updateTask(Task task) async {
    final next = [
      for (final t in _current) (t.id == task.id ? task : t),
    ];
    await _commit(next);
    _rescheduleAll(next);
  }

  /// Toggles a single subtask's completed state on its parent.
  Future<void> toggleSubtask(String taskId, String subtaskId) async {
    final next = [
      for (final t in _current)
        if (t.id == taskId)
          t.copyWith(
            subtasks: [
              for (final s in t.subtasks)
                if (s.id == subtaskId)
                  s.copyWith(completed: !s.completed)
                else
                  s,
            ],
          )
        else
          t,
    ];
    await _commit(next);
  }

  // ---------------- Bulk operations (multi-select) ----------------

  Future<void> bulkComplete(Set<String> ids, DateTime onDay) async {
    final next = <Task>[];
    for (final t in _current) {
      if (!ids.contains(t.id)) {
        next.add(t);
        continue;
      }
      if (t.isRecurring) {
        final d = dateOnly(onDay);
        if (t.completedDates.any((x) => sameDay(x, d))) {
          next.add(t);
        } else {
          next.add(t.copyWith(completedDates: {...t.completedDates, d}));
        }
      } else {
        next.add(t.copyWith(completed: true));
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
