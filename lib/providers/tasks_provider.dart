import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';

const _uuid = Uuid();

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super(_sampleTasks());

  void add(Task task) => state = [...state, task];

  void remove(String id) => state = state.where((t) => t.id != id).toList();

  void toggle(String id) => state = state
      .map((t) => t.id == id ? t.copyWith(completed: !t.completed) : t)
      .toList();

  void update(Task task) =>
      state = state.map((t) => t.id == task.id ? task : t).toList();
}

final tasksProvider =
    StateNotifierProvider<TasksNotifier, List<Task>>((ref) => TasksNotifier());

/// All tasks active on the given [day] — single-day tasks whose start matches,
/// and multi-day tasks whose span covers [day].
final tasksForDayProvider = Provider.family<List<Task>, DateTime>((ref, day) {
  final tasks = ref.watch(tasksProvider);
  return tasks.where((t) => t.occursOn(day)).toList();
});

List<Task> _sampleTasks() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return [
    Task(
      id: _uuid.v4(),
      title: 'Submit assignment',
      startDate: today,
      priority: TaskPriority.high,
      color: const Color(0xFFAB47BC),
    ),
    Task(
      id: _uuid.v4(),
      title: 'Read chapter 4',
      startDate: today,
      priority: TaskPriority.medium,
      color: const Color(0xFFAB47BC),
      completed: true,
    ),
    Task(
      id: _uuid.v4(),
      title: 'Prepare presentation',
      startDate: today.add(const Duration(days: 2)),
      priority: TaskPriority.high,
      color: const Color(0xFF5C6BC0),
    ),
    Task(
      id: _uuid.v4(),
      title: 'Exams',
      startDate: today.subtract(const Duration(days: 1)),
      endDate: today.add(const Duration(days: 3)),
      priority: TaskPriority.high,
      color: const Color(0xFFEF5350),
    ),
    Task(
      id: _uuid.v4(),
      title: 'Hackathon',
      startDate: today.add(const Duration(days: 6)),
      endDate: today.add(const Duration(days: 8)),
      priority: TaskPriority.medium,
      color: const Color(0xFF42A5F5),
    ),
    Task(
      id: _uuid.v4(),
      title: 'Gym Week',
      startDate: today.add(const Duration(days: 11)),
      endDate: today.add(const Duration(days: 15)),
      priority: TaskPriority.low,
      color: const Color(0xFF66BB6A),
    ),
  ];
}
