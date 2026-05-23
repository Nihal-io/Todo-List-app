import '../models/app_settings.dart';

const List<String> kShortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> kWeekdayShortM = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// Format a single day according to the user's [DateFormatPref].
String formatDate(DateTime date, DateFormatPref pref) {
  switch (pref) {
    case DateFormatPref.monthDay:
      return '${kShortMonths[date.month - 1]} ${date.day}';
    case DateFormatPref.dayMonth:
      return '${date.day} ${kShortMonths[date.month - 1]}';
    case DateFormatPref.slash:
      final dd = date.day.toString().padLeft(2, '0');
      final mm = date.month.toString().padLeft(2, '0');
      return '$dd/$mm';
  }
}

/// Format a date that should include the year (e.g. add-sheet pickers).
String formatDateLong(DateTime date, DateFormatPref pref) {
  switch (pref) {
    case DateFormatPref.monthDay:
      return '${kShortMonths[date.month - 1]} ${date.day}, ${date.year}';
    case DateFormatPref.dayMonth:
      return '${date.day} ${kShortMonths[date.month - 1]} ${date.year}';
    case DateFormatPref.slash:
      final dd = date.day.toString().padLeft(2, '0');
      final mm = date.month.toString().padLeft(2, '0');
      return '$dd/$mm/${date.year}';
  }
}

/// Format an inclusive date range using [formatDate] for each end.
String formatDateRange(DateTime start, DateTime end, DateFormatPref pref) {
  return '${formatDate(start, pref)} – ${formatDate(end, pref)}';
}
