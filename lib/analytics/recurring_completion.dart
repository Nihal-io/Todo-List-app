import '../models/task.dart';
import '../shared/date_utils.dart';

/// Default lookback for recurring analytics (matches the overall chart).
const int kRecurringAnalyticsWindowDays = 21;

/// Per-day completion credit for one recurring occurrence.
///
/// Returns `1.0` when the day is ticked in [Task.completedDates]. For today
/// only, open subtasks contribute partial credit. Past missed days return `0.0`.
double recurringDayCompletionCredit(
  Task task,
  DateTime day,
  DateTime today,
) {
  final isDone = task.completedDates.any((c) => sameDay(c, day));
  if (isDone) return 1.0;
  if (!task.hasSubtasks) return 0.0;
  if (sameDay(day, today)) {
    return task.completedSubtaskCount / task.subtasks.length;
  }
  return 0.0;
}

/// Total completion rate across every scheduled recurring occurrence in the
/// window up to [today]. Missed past days count as zero credit, so the rate
/// drops when habits are skipped.
double? totalRecurringCompletionRate(
  List<Task> recurring,
  DateTime today, {
  int windowDays = kRecurringAnalyticsWindowDays,
}) {
  final todayD = dateOnly(today);
  var creditSum = 0.0;
  var slotCount = 0;

  for (var i = windowDays - 1; i >= 0; i--) {
    final d = todayD.subtract(Duration(days: i));
    for (final t in recurring) {
      if (d.isBefore(dateOnly(t.startDate))) continue;
      if (!t.recurrence!.appliesOn(d)) continue;
      slotCount++;
      creditSum += recurringDayCompletionCredit(t, d, todayD);
    }
  }

  if (slotCount == 0) return null;
  return creditSum / slotCount;
}

/// Share of one-off tasks (not events, not recurring) whose deadline has
/// passed and that are still incomplete — i.e. currently overdue.
///
/// Recurring tasks are excluded because they never use the overdue mechanic.
double? oneOffOverdueRate(List<Task> tasks, DateTime today) {
  final todayD = dateOnly(today);
  var eligible = 0;
  var overdue = 0;

  for (final t in tasks) {
    if (t.isEvent || t.isRecurring) continue;
    final due = dateOnly(t.endDate ?? t.startDate);
    if (todayD.isBefore(due)) continue;
    eligible++;
    if (t.isOverdueOn(todayD)) overdue++;
  }

  if (eligible == 0) return null;
  return overdue / eligible;
}
