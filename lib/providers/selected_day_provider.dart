import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The day currently selected in the calendar. Shared so the Add sheet can
/// default new tasks to this day when invoked while the calendar is visible.
final selectedCalendarDayProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// At most one Calendar day-panel row shows inline subtasks at a time.
final calendarExpandedSubtaskTaskIdProvider =
    NotifierProvider<CalendarExpandedSubtaskTaskIdNotifier, String?>(
  CalendarExpandedSubtaskTaskIdNotifier.new,
);

class CalendarExpandedSubtaskTaskIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void toggle(String id) => state = state == id ? null : id;

  void collapse() => state = null;
}
