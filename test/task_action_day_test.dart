import 'package:flutter_test/flutter_test.dart';
import 'package:todo_list/features/home/home_task_sort.dart';
import 'package:todo_list/models/task.dart';

void main() {
  group('Task.actionDayForRow', () {
    final gym = Task(
      id: 'gym',
      title: 'Gym',
      startDate: DateTime(2026, 5, 1),
      recurrence: const WeeklyRecurrence(
        weekdays: {DateTime.monday, DateTime.wednesday, DateTime.friday},
      ),
    );

    test('upcoming section uses next occurrence when not active today', () {
      // Sunday 2026-05-24 — Gym is Mon/Wed/Fri only.
      final sunday = DateTime(2026, 5, 24);
      expect(gym.isActiveOn(sunday), isFalse);

      final actionDay =
          gym.actionDayForRow(sunday, inUpcomingSection: true);
      expect(actionDay, DateTime(2026, 5, 25)); // Monday
    });

    test('current section uses today when active', () {
      final monday = DateTime(2026, 5, 25);
      expect(gym.isActiveOn(monday), isTrue);

      final actionDay =
          gym.actionDayForRow(monday, inUpcomingSection: false);
      expect(actionDay, monday);
    });
  });

  group('Home upcoming recurring completion', () {
    test('row shows done after toggling next occurrence', () {
      final yoga = Task(
        id: 'yoga',
        title: 'Yoga',
        startDate: DateTime(2026, 5, 1),
        recurrence: const WeeklyRecurrence(
          weekdays: {DateTime.tuesday, DateTime.thursday},
        ),
      );

      final sunday = DateTime(2026, 5, 24);
      final next = yoga.actionDayForRow(sunday, inUpcomingSection: true);
      expect(next, DateTime(2026, 5, 26)); // Tuesday

      final completed = yoga.copyWith(
        completedDates: {DateTime(2026, 5, 26)},
      );

      expect(
        completed.isRowDoneOnDate(sunday, inUpcomingSection: true),
        isTrue,
      );
      expect(
        yoga.isRowDoneOnDate(sunday, inUpcomingSection: true),
        isFalse,
      );
    });

    test('upcoming sort treats recurring completion as done tier', () {
      final yoga = Task(
        id: 'yoga',
        title: 'Yoga',
        startDate: DateTime(2026, 5, 1),
        recurrence: const WeeklyRecurrence(
          weekdays: {DateTime.tuesday, DateTime.thursday},
        ),
        completedDates: {DateTime(2026, 5, 26)},
      );

      final sunday = DateTime(2026, 5, 24);
      final open = Task(
        id: 'open',
        title: 'Open',
        startDate: DateTime(2026, 5, 30),
      );

      expect(
        compareUpcomingTasks(yoga, open, sunday),
        isPositive,
      );
    });
  });
}
