import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';

enum TaskStatusFilter { any, open, done }

enum TaskKindFilter { any, task, event, recurring }

@immutable
class TaskFilter {
  const TaskFilter({
    this.query = '',
    this.quadrants = const <MatrixQuadrant>{},
    this.priorities = const <TaskPriority>{},
    this.status = TaskStatusFilter.any,
    this.kind = TaskKindFilter.any,
  });

  final String query;
  final Set<MatrixQuadrant> quadrants;
  final Set<TaskPriority> priorities;
  final TaskStatusFilter status;
  final TaskKindFilter kind;

  bool get isActive =>
      query.trim().isNotEmpty ||
      quadrants.isNotEmpty ||
      priorities.isNotEmpty ||
      status != TaskStatusFilter.any ||
      kind != TaskKindFilter.any;

  TaskFilter copyWith({
    String? query,
    Set<MatrixQuadrant>? quadrants,
    Set<TaskPriority>? priorities,
    TaskStatusFilter? status,
    TaskKindFilter? kind,
  }) =>
      TaskFilter(
        query: query ?? this.query,
        quadrants: quadrants ?? this.quadrants,
        priorities: priorities ?? this.priorities,
        status: status ?? this.status,
        kind: kind ?? this.kind,
      );

  /// Pure filtering — call from any list before display.
  List<Task> apply(List<Task> tasks, DateTime referenceDay) {
    if (!isActive) return tasks;
    final q = query.trim().toLowerCase();
    return tasks.where((t) {
      if (q.isNotEmpty) {
        final inTitle = t.title.toLowerCase().contains(q);
        final inNotes = t.notes.toLowerCase().contains(q);
        final inSub =
            t.subtasks.any((s) => s.title.toLowerCase().contains(q));
        final inTags = t.tags.any((s) => s.toLowerCase().contains(q));
        if (!(inTitle || inNotes || inSub || inTags)) return false;
      }
      if (quadrants.isNotEmpty && !quadrants.contains(t.quadrant)) {
        return false;
      }
      if (priorities.isNotEmpty && !priorities.contains(t.priority)) {
        return false;
      }
      switch (status) {
        case TaskStatusFilter.any:
          break;
        case TaskStatusFilter.open:
          if (t.isCompletedOn(referenceDay)) return false;
          break;
        case TaskStatusFilter.done:
          if (!t.isCompletedOn(referenceDay)) return false;
          break;
      }
      switch (kind) {
        case TaskKindFilter.any:
          break;
        case TaskKindFilter.task:
          if (t.kind != TaskKind.task) return false;
          if (t.isRecurring) return false;
          break;
        case TaskKindFilter.event:
          if (!t.isEvent) return false;
          break;
        case TaskKindFilter.recurring:
          if (!t.isRecurring) return false;
          break;
      }
      return true;
    }).toList();
  }
}

/// Filter shared by Home and Grid View. Lives in memory only — explicitly
/// cleared on each app boot since users rarely want to inherit a filter
/// across sessions.
final taskFilterProvider =
    StateProvider<TaskFilter>((ref) => const TaskFilter());

/// Whether the search bar is currently visible on Home / Grid screens.
final searchBarOpenProvider = StateProvider<bool>((ref) => false);
