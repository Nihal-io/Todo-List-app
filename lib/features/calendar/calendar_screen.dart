import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/app_settings.dart';
import '../../models/task.dart';
import '../../providers/selected_day_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_format.dart';
import '../../theme/app_theme.dart';
import 'add_item_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final selectedDay = ref.watch(selectedCalendarDayProvider);
    final allTasks = ref.watch(tasksProvider);
    final settings = ref.watch(resolvedSettingsProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);

    Color colorFor(Task t) => quadrantColors[t.quadrant] ?? t.color;

    // Multi-day non-recurring tasks (incl. events) → bars
    List<Task> spanningFor(DateTime day) =>
        allTasks.where((t) => t.isMultiDay && t.isActiveOn(day)).toList();

    // Everything else active that day (single-day non-recurring + recurring) → dots
    List<Task> dotsFor(DateTime day) =>
        allTasks.where((t) => !t.isMultiDay && t.isActiveOn(day)).toList();

    final now = _today();

    Widget dayCell(DateTime day, bool isSelected) {
      final isToday = isSameDay(day, now);
      return _DayCell(
        day: day,
        isToday: isToday,
        isSelected: isSelected,
        spanningTasks: spanningFor(day),
        dotTasks: dotsFor(day),
        primary: primary,
        colorFor: colorFor,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: AppSemanticColors.tileBackground(context),
            child: TableCalendar(
              firstDay: DateTime(2020),
              lastDay: DateTime(2030),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, selectedDay),
              onDaySelected: (selected, focused) {
                ref.read(selectedCalendarDayProvider.notifier).state =
                    DateTime(selected.year, selected.month, selected.day);
                setState(() => _focusedDay = focused);
              },
              onPageChanged: (focused) =>
                  setState(() => _focusedDay = focused),
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month'
              },
              startingDayOfWeek: settings.firstDayOfWeek.startingDayOfWeek,
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.symmetric(vertical: 1),
                cellPadding: EdgeInsets.zero,
              ),
              rowHeight: 64,
              daysOfWeekHeight: 32,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  size: 24,
                  color: AppSemanticColors.textStrong(context),
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: AppSemanticColors.textStrong(context),
                ),
                leftChevronMargin: const EdgeInsets.symmetric(horizontal: 8),
                rightChevronMargin: const EdgeInsets.symmetric(horizontal: 8),
                headerPadding: const EdgeInsets.symmetric(vertical: 12),
                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppSemanticColors.textStrong(context),
                  letterSpacing: -0.3,
                ),
                leftChevronPadding: const EdgeInsets.all(8),
                rightChevronPadding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppSemanticColors.textFaint(context),
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppSemanticColors.navInactive(context),
                ),
              ),
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (_, day, __) => dayCell(day, false),
                todayBuilder: (_, day, __) => dayCell(day, false),
                selectedBuilder: (_, day, __) => dayCell(day, true),
                outsideBuilder: (_, day, __) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _DayHeader(
            selectedDay: selectedDay,
            dateFormat: settings.dateFormat,
          ),
          const Divider(height: 1),
          Expanded(
            child: _DayPanel(
              selectedDay: selectedDay,
              density: settings.density,
              dateFormat: settings.dateFormat,
              colorFor: colorFor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day cell — date number, dots (single-day + recurring), spanning bars
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.spanningTasks,
    required this.dotTasks,
    required this.primary,
    required this.colorFor,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final List<Task> spanningTasks;
  final List<Task> dotTasks;
  final Color primary;
  final Color Function(Task) colorFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: isSelected
                ? BoxDecoration(color: primary, shape: BoxShape.circle)
                : isToday
                    ? BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      )
                    : null,
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : isToday
                          ? primary
                          : AppSemanticColors.textStrong(context),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (dotTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in dotTasks.take(3))
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: colorFor(t),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (dotTasks.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '+${dotTasks.length - 3}',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        color: primary,
                        height: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ...spanningTasks
            .take(2)
            .map((t) => _BarSegment(task: t, day: day, color: colorFor(t))),
        if (spanningTasks.length > 2)
          Container(
            height: 6,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Text(
              '+${spanningTasks.length - 2}',
              style: TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w800,
                color: primary,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spanning bar segment — adjacent same-color cells visually connect.
// Events render at lower opacity to read as ambient context.
// ---------------------------------------------------------------------------

class _BarSegment extends StatelessWidget {
  const _BarSegment({
    required this.task,
    required this.day,
    required this.color,
  });

  final Task task;
  final DateTime day;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isStart = task.isStartDay(day);
    final isEnd = task.isEndDay(day);
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;

    final capLeft = isStart || isSunday;
    final capRight = isEnd || isSaturday;

    final paint = task.isEvent ? color.withValues(alpha: 0.5) : color;

    return Container(
      height: 6,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: paint,
        borderRadius: BorderRadius.horizontal(
          left: capLeft ? const Radius.circular(3) : Radius.zero,
          right: capRight ? const Radius.circular(3) : Radius.zero,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day header
// ---------------------------------------------------------------------------

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.selectedDay,
    required this.dateFormat,
  });

  final DateTime selectedDay;
  final DateFormatPref dateFormat;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (isSameDay(selectedDay, today)) return 'Today';
    if (isSameDay(selectedDay, tomorrow)) return 'Tomorrow';
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return '${weekdays[selectedDay.weekday - 1]}, '
        '${formatDate(selectedDay, dateFormat)}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Text(
        _label(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppSemanticColors.textStrong(context),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day panel — flat list of all tasks active on the selected day
// ---------------------------------------------------------------------------

class _DayPanel extends ConsumerWidget {
  const _DayPanel({
    required this.selectedDay,
    required this.density,
    required this.dateFormat,
    required this.colorFor,
  });

  final DateTime selectedDay;
  final DensityPref density;
  final DateFormatPref dateFormat;
  final Color Function(Task) colorFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksForDayProvider(selectedDay));

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No tasks for this day',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    int rank(Task t) {
      if (t.isEvent) return 0;
      if (t.isMultiDay) return 1;
      return 2;
    }

    final sorted = [...tasks]
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        return b.priority.index.compareTo(a.priority.index);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
          final t = sorted[i];
          return _TaskTile(
            task: t,
            selectedDay: selectedDay,
            density: density,
            dateFormat: dateFormat,
            accentColor: colorFor(t),
            onToggle: () => ref
                .read(tasksProvider.notifier)
                .toggleForDay(t.id, selectedDay),
            onEdit: () => showAddItemSheet(context, taskToEdit: t),
          );
        },
    );
  }
}

// ---------------------------------------------------------------------------
// Task tile — renders task/event/recurring shapes from a single widget.
// ---------------------------------------------------------------------------

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.selectedDay,
    required this.onToggle,
    required this.density,
    required this.dateFormat,
    required this.accentColor,
    required this.onEdit,
  });

  final Task task;
  final DateTime selectedDay;
  final VoidCallback onToggle;
  final DensityPref density;
  final DateFormatPref dateFormat;
  final Color accentColor;
  final VoidCallback onEdit;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.high:
        return const Color(0xFFEF5350);
      case TaskPriority.medium:
        return const Color(0xFFFF9800);
      case TaskPriority.low:
        return const Color(0xFF66BB6A);
    }
  }

  String? _subtitle() {
    if (task.isMultiDay) {
      final range =
          formatDateRange(task.startDate, task.endDate!, dateFormat);
      if (task.isEvent && task.hasAutoCompleted) return '$range  ·  Ended';
      return range;
    }
    if (task.isRecurring) {
      final days = (task.recurrence!.weekdays.toList()..sort())
          .map((w) => _weekdayShort[w - 1])
          .join(' ');
      final until = task.recurrence!.until;
      if (until == null) return 'Repeats $days  ·  Forever';
      return 'Repeats $days  ·  until '
          '${formatDate(until, dateFormat)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle();
    final isDone = task.isCompletedOn(selectedDay);
    final m = density.paddingMultiplier;
    final hPad = 14 * m;
    final vPad = 12 * m;
    final tileGap = (8 * m).round().toDouble();

    return Container(
      margin: EdgeInsets.only(bottom: tileGap),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.softShadow(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onToggle,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone
                        ? AppSemanticColors.successGreen
                        : AppSemanticColors.subtleBorder(context),
                    width: 2,
                  ),
                  color: isDone
                      ? AppSemanticColors.successGreen
                      : Colors.transparent,
                ),
                child: isDone
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? AppSemanticColors.textFaint(context)
                            : AppSemanticColors.textStrong(context),
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppSemanticColors.textFaint(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppSemanticColors.textFaint(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!task.isEvent)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _priorityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _priorityColor,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
