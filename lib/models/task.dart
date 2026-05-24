import 'package:flutter/material.dart';

import '../shared/date_utils.dart';
import 'sub_task.dart';

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
    if (until != null && dateOnly(day).isAfter(dateOnly(until!))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'weekdays': weekdays.toList()..sort(),
        if (until != null) 'until': until!.toIso8601String(),
      };

  factory WeeklyRecurrence.fromJson(Map<String, dynamic> json) {
    final raw = json['weekdays'];
    final wd = <int>{};
    if (raw is List) {
      for (final v in raw) {
        if (v is int) {
          wd.add(v);
        } else if (v is num) {
          wd.add(v.toInt());
        }
      }
    }
    final untilStr = json['until'];
    final until = untilStr is String ? DateTime.tryParse(untilStr) : null;
    return WeeklyRecurrence(weekdays: wd, until: until);
  }
}

/// Wall-clock time slice (HH:mm) stored as minutes since midnight.
@immutable
class TaskTime {
  const TaskTime({required this.hour, required this.minute});

  factory TaskTime.fromTimeOfDay(TimeOfDay t) =>
      TaskTime(hour: t.hour, minute: t.minute);

  final int hour;
  final int minute;

  int get minutesSinceMidnight => hour * 60 + minute;

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  /// 12-hour formatted string (e.g. `9:30 AM`).
  String formatTwelveHour() {
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  Map<String, dynamic> toJson() => {'h': hour, 'm': minute};

  factory TaskTime.fromJson(Map<String, dynamic> json) => TaskTime(
        hour: (json['h'] as num?)?.toInt() ?? 0,
        minute: (json['m'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is TaskTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
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
    this.notes = '',
    List<SubTask>? subtasks,
    this.startTime,
    this.endTime,
    List<String>? tags,
    double? sortIndex,
  })  : completedDates = completedDates ?? <DateTime>{},
        subtasks = subtasks ?? const <SubTask>[],
        tags = tags ?? const <String>[],
        sortIndex =
            sortIndex ?? DateTime.now().microsecondsSinceEpoch.toDouble();

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

  /// Free-form long-form description / context for the task.
  final String notes;

  /// Nested checkable items. Empty by default; surfaced in the detail sheet
  /// but not in the compact row tiles.
  final List<SubTask> subtasks;

  /// Optional start-of-day clock time. Useful for events that begin at a
  /// specific hour (e.g. "Hackathon at 10:00 AM").
  final TaskTime? startTime;

  /// Optional end-of-day clock time, paired with [startTime].
  final TaskTime? endTime;

  /// Free-form labels orthogonal to quadrant.
  final List<String> tags;

  /// Persistent ordering hint used by drag-to-reorder. Lower comes first.
  /// Defaults to a creation timestamp so insertion order is preserved when
  /// no manual reorder has occurred.
  final double sortIndex;

  Color get color => quadrant.color;

  bool get isEvent => kind == TaskKind.event;
  bool get isRecurring => recurrence != null;
  bool get isMultiDay => !isRecurring && endDate != null;

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get completedSubtaskCount =>
      subtasks.where((s) => s.completed).length;

  bool isActiveOn(DateTime day) {
    final d = dateOnly(day);
    if (isRecurring) return recurrence!.appliesOn(d);
    final s = dateOnly(startDate);
    final e = endDate == null ? s : dateOnly(endDate!);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  bool isStartDay(DateTime day) => sameDay(day, startDate);

  bool isEndDay(DateTime day) => sameDay(day, endDate ?? startDate);

  /// Event auto-completion relative to [today].
  ///
  /// Note: callers who need reactivity to the clock provider should compare
  /// against a passed-in `today` instead of calling this getter, which reads
  /// `DateTime.now()` directly and may lag behind the reactive clock.
  bool autoCompletedOn(DateTime today) {
    if (!isEvent) return false;
    final e = dateOnly(endDate ?? startDate);
    return dateOnly(today).isAfter(e);
  }

  bool get hasAutoCompleted => autoCompletedOn(DateTime.now());

  bool isCompletedOn(DateTime day) {
    if (isEvent) return completed || autoCompletedOn(day);
    if (isRecurring) {
      return completedDates.any((d) => sameDay(d, day));
    }
    return completed;
  }

  bool isOverdueOn(DateTime day) {
    if (isEvent || isRecurring) return false;
    if (completed) return false;
    final due = dateOnly(endDate ?? startDate);
    return dateOnly(day).isAfter(due);
  }

  /// The next calendar day on or after [after] when this task occurs, or null.
  DateTime? nextOccurrenceAfter(DateTime after) {
    final afterDay = dateOnly(after);
    if (isRecurring) {
      final untilDay =
          recurrence!.until != null ? dateOnly(recurrence!.until!) : null;
      var cursor = afterDay;
      for (var i = 0; i < 730; i++) {
        if (untilDay != null && cursor.isAfter(untilDay)) return null;
        if (recurrence!.appliesOn(cursor)) return cursor;
        cursor = cursor.add(const Duration(days: 1));
      }
      return null;
    }
    final start = dateOnly(startDate);
    if (!start.isBefore(afterDay)) return start;
    return null;
  }

  bool isUpcomingFrom(DateTime today) {
    if (isRecurring) return nextOccurrenceAfter(today) != null;
    if (isEvent) {
      if (completed || autoCompletedOn(today)) return false;
      return dateOnly(startDate).isAfter(dateOnly(today));
    }
    if (completed) return false;
    return dateOnly(startDate).isAfter(dateOnly(today));
  }

  /// When this task next "fires" for a reminder, or null if it never does.
  ///
  /// Uses [startTime] when set, otherwise 9:00 AM. Overdue one-off tasks nudge
  /// on the current day; recurring tasks skip days already completed.
  DateTime? nextReminderAfter(DateTime after) {
    if (isEvent && autoCompletedOn(dateOnly(after))) return null;
    if (!isRecurring && completed) return null;

    final afterDay = dateOnly(after);
    final reminderTime = startTime;
    final hour = reminderTime?.hour ?? 9;
    final minute = reminderTime?.minute ?? 0;

    DateTime atTime(DateTime day) =>
        DateTime(day.year, day.month, day.day, hour, minute);

    if (isRecurring) {
      if (isCompletedOn(afterDay)) {
        final nextDay = nextOccurrenceAfter(
          afterDay.add(const Duration(days: 1)),
        );
        return nextDay == null ? null : atTime(nextDay);
      }
      final day = nextOccurrenceAfter(after);
      if (day == null) return null;
      final candidate = atTime(day);
      if (candidate.isAfter(after)) return candidate;
      return after.add(const Duration(minutes: 1));
    }

    final start = dateOnly(startDate);
    final end = dateOnly(endDate ?? startDate);

    // Active today (including overdue within a multi-day span).
    if (!afterDay.isBefore(start) && !afterDay.isAfter(end)) {
      final candidate = atTime(afterDay);
      if (candidate.isAfter(after)) return candidate;
      return after.add(const Duration(minutes: 1));
    }

    // Future one-off / event.
    if (start.isAfter(afterDay)) return atTime(start);

    // Past deadline but still incomplete — daily nudge at default time.
    if (afterDay.isAfter(end)) {
      final candidate = atTime(afterDay);
      if (candidate.isAfter(after)) return candidate;
      return after.add(const Duration(minutes: 1));
    }

    return null;
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
    String? notes,
    List<SubTask>? subtasks,
    TaskTime? startTime,
    bool clearStartTime = false,
    TaskTime? endTime,
    bool clearEndTime = false,
    List<String>? tags,
    double? sortIndex,
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
      notes: notes ?? this.notes,
      subtasks: subtasks ?? this.subtasks,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      tags: tags ?? this.tags,
      sortIndex: sortIndex ?? this.sortIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'kind': kind.name,
        if (recurrence != null) 'recurrence': recurrence!.toJson(),
        'completed': completed,
        'completedDates': completedDates
            .map((d) => DateTime(d.year, d.month, d.day).toIso8601String())
            .toList(),
        'priority': priority.name,
        'quadrant': quadrant.name,
        if (notes.isNotEmpty) 'notes': notes,
        if (subtasks.isNotEmpty)
          'subtasks': subtasks.map((s) => s.toJson()).toList(),
        if (startTime != null) 'startTime': startTime!.toJson(),
        if (endTime != null) 'endTime': endTime!.toJson(),
        if (tags.isNotEmpty) 'tags': tags,
        'sortIndex': sortIndex,
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    T? enumByName<T extends Enum>(List<T> values, Object? raw) {
      if (raw is! String) return null;
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return null;
    }

    final completedDatesRaw = json['completedDates'];
    final completedDates = <DateTime>{};
    if (completedDatesRaw is List) {
      for (final v in completedDatesRaw) {
        if (v is String) {
          final d = DateTime.tryParse(v);
          if (d != null) completedDates.add(DateTime(d.year, d.month, d.day));
        }
      }
    }

    final subtasksRaw = json['subtasks'];
    final subtasks = <SubTask>[];
    if (subtasksRaw is List) {
      for (final v in subtasksRaw) {
        if (v is Map<String, dynamic>) {
          subtasks.add(SubTask.fromJson(v));
        } else if (v is Map) {
          subtasks.add(SubTask.fromJson(v.cast<String, dynamic>()));
        }
      }
    }

    final tagsRaw = json['tags'];
    final tags = <String>[];
    if (tagsRaw is List) {
      for (final v in tagsRaw) {
        if (v is String) tags.add(v);
      }
    }

    TaskTime? readTime(Object? raw) {
      if (raw is Map<String, dynamic>) return TaskTime.fromJson(raw);
      if (raw is Map) return TaskTime.fromJson(raw.cast<String, dynamic>());
      return null;
    }

    final recurrenceRaw = json['recurrence'];
    WeeklyRecurrence? recurrence;
    if (recurrenceRaw is Map<String, dynamic>) {
      recurrence = WeeklyRecurrence.fromJson(recurrenceRaw);
    } else if (recurrenceRaw is Map) {
      recurrence =
          WeeklyRecurrence.fromJson(recurrenceRaw.cast<String, dynamic>());
    }

    return Task(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: (json['endDate'] is String)
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
      kind: enumByName(TaskKind.values, json['kind']) ?? TaskKind.task,
      recurrence: recurrence,
      completed: json['completed'] as bool? ?? false,
      completedDates: completedDates,
      priority:
          enumByName(TaskPriority.values, json['priority']) ?? TaskPriority.medium,
      quadrant: enumByName(MatrixQuadrant.values, json['quadrant']) ??
          kDefaultQuadrant,
      notes: json['notes'] as String? ?? '',
      subtasks: subtasks,
      startTime: readTime(json['startTime']),
      endTime: readTime(json['endTime']),
      tags: tags,
      sortIndex: (json['sortIndex'] as num?)?.toDouble() ??
          DateTime.now().microsecondsSinceEpoch.toDouble(),
    );
  }
}
