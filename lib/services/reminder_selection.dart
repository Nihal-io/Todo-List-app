import '../features/home/home_task_sort.dart';
import '../models/task.dart';
import '../shared/date_utils.dart';

/// How many upcoming tasks to surface when nothing is due today.
const int kMaxUpcomingReminderTasks = 5;

/// Pending tasks for [day]: active today plus overdue one-offs not yet done.
List<Task> pendingTasksForDay(List<Task> tasks, DateTime day) {
  final d = dateOnly(day);
  return tasks
      .where((t) {
        if (t.isCompletedOn(d)) return false;
        if (t.isActiveOn(d)) return true;
        if (!t.isEvent && !t.isRecurring && t.isOverdueOn(d)) return true;
        return false;
      })
      .toList()
    ..sort((a, b) => compareCurrentTasks(a, b, d));
}

bool _isUpcomingCandidate(Task t, DateTime today) {
  if (t.isRecurring) {
    final next = t.nextOccurrenceAfter(today);
    return next != null && dateOnly(next).isAfter(today);
  }
  if (t.isEvent) {
    if (t.completed || t.autoCompletedOn(today)) return false;
    return dateOnly(t.startDate).isAfter(today);
  }
  if (t.completed) return false;
  return dateOnly(t.startDate).isAfter(today);
}

/// Top [kMaxUpcomingReminderTasks] upcoming tasks when nothing is due today.
List<Task> topUpcomingTasks(List<Task> tasks, DateTime day) {
  final d = dateOnly(day);
  return tasks.where((t) => _isUpcomingCandidate(t, d)).toList()
    ..sort((a, b) => compareUpcomingTasks(a, b, d));
}

/// Tasks that should receive scheduled alarms.
///
/// - Today's pending items (one-offs due today, recurring tasks that apply
///   today and aren't yet ticked).
/// - **Plus** every recurring task that still has a future occurrence,
///   regardless of whether today is one of its applicable days. The
///   recurring scheduler queues 24 future alarms per task, and if the
///   task is missing from the targets set on a non-applicable day the
///   rescheduler will cancel all of those queued alarms — silently
///   breaking notifications until the app is reopened on the next
///   applicable day.
/// - If both sets are empty, fall back to the nearest upcoming tasks.
List<Task> tasksForScheduledReminders(List<Task> tasks, [DateTime? day]) {
  final today = dateOnly(day ?? DateTime.now());
  final seen = <String>{};
  final out = <Task>[];
  for (final t in pendingTasksForDay(tasks, today)) {
    if (seen.add(t.id)) out.add(t);
  }
  for (final t in tasks) {
    if (!t.isRecurring) continue;
    if (t.nextOccurrenceAfter(today) == null) continue;
    if (seen.add(t.id)) out.add(t);
  }
  if (out.isNotEmpty) return out;
  return topUpcomingTasks(tasks, today).take(kMaxUpcomingReminderTasks).toList();
}

/// Title + body copy for the Android foreground-service notification.
({String title, String body}) foregroundSummaryFor(
  List<Task> tasks,
  DateTime day,
) {
  final d = dateOnly(day);
  final pendingToday = pendingTasksForDay(tasks, d);
  final activeToday = tasks
      .where((t) => t.isActiveOn(d) || (!t.isEvent && !t.isRecurring && t.isOverdueOn(d)))
      .toList();
  final doneToday = activeToday.where((t) => t.isCompletedOn(d)).length;

  if (pendingToday.isNotEmpty) {
    return (
      title: 'Today: $doneToday of ${activeToday.length} done',
      body: _bulletList(pendingToday.map((t) => t.title)),
    );
  }

  final upcoming = topUpcomingTasks(tasks, d);
  if (upcoming.isEmpty) {
    return (
      title: 'Nothing scheduled today',
      body: 'All caught up — nice work!',
    );
  }

  final shown = upcoming.take(kMaxUpcomingReminderTasks).toList();
  return (
    title: 'Upcoming: ${shown.length} ${shown.length == 1 ? 'item' : 'items'}',
    body: _bulletList(shown.map((t) => t.title)),
  );
}

String _bulletList(Iterable<String> lines) {
  const maxLines = 3;
  final items = lines.take(maxLines).map((t) => '• $t').toList();
  if (items.isEmpty) return 'All caught up — nice work!';
  final summary = items.join('\n');
  final total = lines.length;
  if (total > maxLines) {
    return '$summary\n+ ${total - maxLines} more';
  }
  return summary;
}
