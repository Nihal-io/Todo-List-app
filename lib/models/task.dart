import 'package:flutter/material.dart';

enum TaskPriority { low, medium, high }

enum TaskKind { task, event }

enum MatrixQuadrant {
  /// Urgent & Important — do it now.
  doFirst,
  /// Not Urgent & Important — plan and schedule it.
  schedule,
  /// Urgent & Not Important — delegate it.
  delegate,
  /// Not Urgent & Not Important — eliminate it.
  eliminate;

  Color get color {
    switch (this) {
      case MatrixQuadrant.doFirst:
        return const Color(0xFFEF5350);
      case MatrixQuadrant.schedule:
        return const Color(0xFF42A5F5);
      case MatrixQuadrant.delegate:
        return const Color(0xFFFFA726);
      case MatrixQuadrant.eliminate:
        return const Color(0xFF90A4AE);
    }
  }

  String get label {
    switch (this) {
      case MatrixQuadrant.doFirst:
        return 'Do';
      case MatrixQuadrant.schedule:
        return 'Schedule';
      case MatrixQuadrant.delegate:
        return 'Delegate';
      case MatrixQuadrant.eliminate:
        return 'Eliminate';
    }
  }

  String get subtitle {
    switch (this) {
      case MatrixQuadrant.doFirst:
        return 'Urgent & Important';
      case MatrixQuadrant.schedule:
        return 'Not Urgent & Important';
      case MatrixQuadrant.delegate:
        return 'Urgent & Not Important';
      case MatrixQuadrant.eliminate:
        return 'Not Urgent & Not Important';
    }
  }
}

const MatrixQuadrant kDefaultQuadrant = MatrixQuadrant.schedule;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Weekly recurrence rule. `weekdays` uses `DateTime.weekday` values
/// (1 = Monday ... 7 = Sunday). `until` is the last day the rule applies on;
/// `null` means the rule repeats forever.
class WeeklyRecurrence {
  const WeeklyRecurrence({required this.weekdays, this.until});

  final Set<int> weekdays;
  final DateTime? until;

  bool appliesOn(DateTime day) {
    if (weekdays.isEmpty) return false;
    if (!weekdays.contains(day.weekday)) return false;
    if (until != null && _dateOnly(day).isAfter(_dateOnly(until!))) {
      return false;
    }
    return true;
  }
}

class Task {
  Task({
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    this.kind = TaskKind.task,
    this.recurrence,
    this.completed = false,
    Set<DateTime>? completedDates,
    this.priority = TaskPriority.medium,
    this.quadrant = kDefaultQuadrant,
  }) : completedDates = completedDates ?? <DateTime>{};

  final String id;
  final String title;
  final DateTime startDate;

  /// Multi-day span; required for events.
  final DateTime? endDate;

  final TaskKind kind;

  /// `null` for non-recurring tasks. Recurring tasks ignore [endDate].
  final WeeklyRecurrence? recurrence;

  /// Single tick for non-recurring tasks.
  final bool completed;

  /// Per-day ticks for recurring tasks (date-only entries).
  final Set<DateTime> completedDates;

  final TaskPriority priority;
  final MatrixQuadrant quadrant;

  Color get color => quadrant.color;

  bool get isEvent => kind == TaskKind.event;
  bool get isRecurring => recurrence != null;
  bool get isMultiDay => !isRecurring && endDate != null;

  /// True if this task is visible / actionable on [day].
  bool isActiveOn(DateTime day) {
    final d = _dateOnly(day);
    if (isRecurring) return recurrence!.appliesOn(d);
    final s = _dateOnly(startDate);
    final e = endDate == null ? s : _dateOnly(endDate!);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool isStartDay(DateTime day) => _sameDay(day, startDate);

  bool isEndDay(DateTime day) =>
      _sameDay(day, endDate ?? startDate);

  /// Event auto-completes once its end date has passed.
  bool get hasAutoCompleted {
    if (!isEvent) return false;
    final today = _dateOnly(DateTime.now());
    final e = _dateOnly(endDate ?? startDate);
    return today.isAfter(e);
  }

  bool isCompletedOn(DateTime day) {
    if (isEvent) return completed || hasAutoCompleted;
    if (isRecurring) {
      return completedDates.any((d) => _sameDay(d, day));
    }
    return completed;
  }

  bool isOverdueOn(DateTime day) {
    if (isEvent || isRecurring) return false;
    if (completed) return false;
    final due = _dateOnly(endDate ?? startDate);
    return _dateOnly(day).isAfter(due);
  }

  /// The next day after [after] when this task occurs, or null if none.
  DateTime? nextOccurrenceAfter(DateTime after) {
    final afterDay = _dateOnly(after);
    if (isRecurring) {
      var cursor = afterDay.add(const Duration(days: 1));
      final untilDay =
          recurrence!.until != null ? _dateOnly(recurrence!.until!) : null;
      // Search up to ~2 years ahead.
      for (var i = 0; i < 730; i++) {
        if (untilDay != null && cursor.isAfter(untilDay)) return null;
        if (recurrence!.appliesOn(cursor)) return cursor;
        cursor = cursor.add(const Duration(days: 1));
      }
      return null;
    }
    final start = _dateOnly(startDate);
    if (start.isAfter(afterDay)) return start;
    return null;
  }

  /// Whether this task belongs in the Home "Upcoming" tab (relative to [today]).
  bool isUpcomingFrom(DateTime today) {
    if (isRecurring) return nextOccurrenceAfter(today) != null;
    if (isEvent) {
      if (completed || hasAutoCompleted) return false;
      return _dateOnly(startDate).isAfter(_dateOnly(today));
    }
    if (completed) return false;
    return _dateOnly(startDate).isAfter(_dateOnly(today));
  }

  Task copyWith({
    String? id,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    TaskKind? kind,
    WeeklyRecurrence? recurrence,
    bool clearRecurrence = false,
    bool? completed,
    Set<DateTime>? completedDates,
    TaskPriority? priority,
    MatrixQuadrant? quadrant,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      kind: kind ?? this.kind,
      recurrence:
          clearRecurrence ? null : (recurrence ?? this.recurrence),
      completed: completed ?? this.completed,
      completedDates: completedDates ?? this.completedDates,
      priority: priority ?? this.priority,
      quadrant: quadrant ?? this.quadrant,
    );
  }
}
