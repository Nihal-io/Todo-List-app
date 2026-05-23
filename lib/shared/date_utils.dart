/// Date-only helpers shared across models, providers, and widgets.
///
/// Centralising these here removes duplicate private copies that previously
/// lived in `task.dart`, `tasks_provider.dart`, `home_provider.dart`, etc.
library;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime today() => dateOnly(DateTime.now());
