import 'package:flutter_test/flutter_test.dart';
import 'package:todo_list/analytics/recurring_completion.dart';
import 'package:todo_list/models/task.dart';

void main() {
  final today = DateTime(2026, 5, 25); // Monday

  group('totalRecurringCompletionRate', () {
    test('counts missed past occurrences as zero', () {
      final gym = Task(
        id: 'gym',
        title: 'Gym',
        startDate: today.subtract(const Duration(days: 10)),
        recurrence: const WeeklyRecurrence(weekdays: {DateTime.monday}),
        completedDates: {}, // missed last Monday
      );

      final rate = totalRecurringCompletionRate(
        [gym],
        today,
        windowDays: 14,
      );

      // Only one Monday in the last 14 days including today.
      expect(rate, 0.0);
    });

    test('returns 1.0 when every scheduled day is done', () {
      final lastMonday = today.subtract(const Duration(days: 7));
      final gym = Task(
        id: 'gym',
        title: 'Gym',
        startDate: lastMonday,
        recurrence: const WeeklyRecurrence(weekdays: {DateTime.monday}),
        completedDates: {lastMonday, today},
      );

      expect(
        totalRecurringCompletionRate([gym], today, windowDays: 14),
        1.0,
      );
    });

    test('returns null when nothing was scheduled', () {
      final gym = Task(
        id: 'gym',
        title: 'Gym',
        startDate: today.add(const Duration(days: 5)),
        recurrence: const WeeklyRecurrence(weekdays: {DateTime.monday}),
      );

      expect(
        totalRecurringCompletionRate([gym], today, windowDays: 7),
        isNull,
      );
    });
  });

  group('oneOffOverdueRate', () {
    test('ignores recurring tasks and events', () {
      final tasks = [
        Task(
          id: 'r',
          title: 'Gym',
          startDate: today.subtract(const Duration(days: 30)),
          recurrence: const WeeklyRecurrence(weekdays: {DateTime.monday}),
        ),
        Task(
          id: 'e',
          title: 'Exams',
          startDate: today.subtract(const Duration(days: 2)),
          endDate: today.subtract(const Duration(days: 1)),
          kind: TaskKind.event,
        ),
      ];

      expect(oneOffOverdueRate(tasks, today), isNull);
    });

    test('counts incomplete past-deadline one-offs as overdue', () {
      final tasks = [
        Task(
          id: 'a',
          title: 'Late report',
          startDate: today.subtract(const Duration(days: 3)),
        ),
        Task(
          id: 'b',
          title: 'Done on time',
          startDate: today.subtract(const Duration(days: 2)),
          completed: true,
        ),
        Task(
          id: 'c',
          title: 'Future',
          startDate: today.add(const Duration(days: 2)),
        ),
      ];

      expect(oneOffOverdueRate(tasks, today), closeTo(0.5, 0.001));
    });
  });
}
