import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The day currently selected in the calendar. Shared so the Add sheet can
/// default new tasks to this day when invoked while the calendar is visible.
final selectedCalendarDayProvider = StateProvider<DateTime>((ref) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});
