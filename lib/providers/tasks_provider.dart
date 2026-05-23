import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

const _uuid = Uuid();

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Fresh sample tasks — every item uses a [MatrixQuadrant] for its color.
/// Call [TasksNotifier.reseed] to replace in-memory state with this set.
List<Task> buildSampleTasks() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final endOfNextMonth = DateTime(today.year, today.month + 2, 0);

  return [
    // ── Do First (red) ──────────────────────────────────────────────────
    Task(
      id: _uuid.v4(),
      title: 'Submit assignment',
      startDate: today,
      priority: TaskPriority.high,
      quadrant: MatrixQuadrant.doFirst,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Prepare presentation',
      startDate: today.add(const Duration(days: 2)),
      priority: TaskPriority.high,
      quadrant: MatrixQuadrant.doFirst,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Exams',
      startDate: today.subtract(const Duration(days: 1)),
      endDate: today.add(const Duration(days: 3)),
      kind: TaskKind.event,
      quadrant: MatrixQuadrant.doFirst,
    ),

    // ── Schedule (blue) ─────────────────────────────────────────────────
    Task(
      id: _uuid.v4(),
      title: 'Read chapter 4',
      startDate: today,
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.schedule,
      completed: true,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Write report',
      startDate: today.add(const Duration(days: 1)),
      endDate: today.add(const Duration(days: 3)),
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.schedule,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Hackathon',
      startDate: today.add(const Duration(days: 6)),
      endDate: today.add(const Duration(days: 8)),
      kind: TaskKind.event,
      quadrant: MatrixQuadrant.schedule,
    ),

    // ── Delegate (orange) ───────────────────────────────────────────────
    Task(
      id: _uuid.v4(),
      title: 'Gym',
      startDate: today,
      recurrence: const WeeklyRecurrence(
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      ),
      priority: TaskPriority.low,
      quadrant: MatrixQuadrant.delegate,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Reply to emails',
      startDate: today.subtract(const Duration(days: 2)),
      priority: TaskPriority.medium,
      quadrant: MatrixQuadrant.delegate,
    ),

    // ── Eliminate (grey) ────────────────────────────────────────────────
    Task(
      id: _uuid.v4(),
      title: 'Yoga',
      startDate: today,
      recurrence: WeeklyRecurrence(
        weekdays: const {DateTime.tuesday, DateTime.thursday},
        until: endOfNextMonth,
      ),
      priority: TaskPriority.low,
      quadrant: MatrixQuadrant.eliminate,
    ),
  ];
}

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super(buildSampleTasks());

  /// Replace all tasks with the canonical sample set (matrix colors only).
  void reseed() => state = buildSampleTasks();

  void add(Task task) => state = [...state, task];

  void remove(String id) => state = state.where((t) => t.id != id).toList();

  /// Toggle for non-recurring tasks and events (flips the single `completed` bool).
  /// For recurring tasks use [toggleForDay].
  void toggle(String id) => state = state.map((t) {
        if (t.id != id) return t;
        if (t.isRecurring) return t;
        return t.copyWith(completed: !t.completed);
      }).toList();

  /// Toggle completion for a specific day. Recurring tasks add/remove the day
  /// from `completedDates`. Non-recurring tasks and events flip [completed].
  void toggleForDay(String id, DateTime day) {
    state = state.map((t) {
      if (t.id != id) return t;
      if (t.isRecurring) {
        final d = _dateOnly(day);
        final next = {...t.completedDates};
        final existing = next.where((x) =>
            x.year == d.year && x.month == d.month && x.day == d.day).toList();
        if (existing.isEmpty) {
          next.add(d);
        } else {
          next.removeAll(existing);
        }
        return t.copyWith(completedDates: next);
      }
      return t.copyWith(completed: !t.completed);
    }).toList();
  }

  void update(Task task) =>
      state = state.map((t) => t.id == task.id ? task : t).toList();
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, List<Task>>((ref) => TasksNotifier());

/// All tasks active on the given [day] — handles both non-recurring spans
/// and recurring weekly rules.
final tasksForDayProvider = Provider.family<List<Task>, DateTime>((ref, day) {
  final tasks = ref.watch(tasksProvider);
  return tasks.where((t) => t.isActiveOn(day)).toList();
});
