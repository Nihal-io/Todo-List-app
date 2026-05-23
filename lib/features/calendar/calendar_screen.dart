import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/task.dart';
import '../../providers/selected_day_provider.dart';
import '../../providers/tasks_provider.dart';

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

    List<Task> multiDayFor(DateTime day) =>
        allTasks.where((t) => t.isMultiDay && t.occursOn(day)).toList();

    List<Task> singleDayFor(DateTime day) =>
        allTasks.where((t) => !t.isMultiDay && t.occursOn(day)).toList();

    final now = _today();

    Widget dayCell(DateTime day, bool isSelected) {
      final isToday = isSameDay(day, now);
      return _DayCell(
        day: day,
        isToday: isToday,
        isSelected: isSelected,
        spanningTasks: multiDayFor(day),
        singleDayTasks: singleDayFor(day),
        primary: primary,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          Container(
            color: Colors.white,
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
              startingDayOfWeek: StartingDayOfWeek.sunday,
              calendarStyle: const CalendarStyle(
                outsideDaysVisible: false,
                cellMargin: EdgeInsets.symmetric(vertical: 1),
                cellPadding: EdgeInsets.zero,
              ),
              rowHeight: 64,
              daysOfWeekHeight: 32,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left, size: 24),
                rightChevronIcon: Icon(Icons.chevron_right, size: 24),
                leftChevronMargin: EdgeInsets.symmetric(horizontal: 8),
                rightChevronMargin: EdgeInsets.symmetric(horizontal: 8),
                headerPadding: EdgeInsets.symmetric(vertical: 12),
                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.3,
                ),
                leftChevronPadding: EdgeInsets.all(8),
                rightChevronPadding: EdgeInsets.all(8),
                decoration: BoxDecoration(),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9090A8),
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB0B0C8),
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
          _DayHeader(selectedDay: selectedDay),
          const Divider(height: 1),
          Expanded(child: _DayPanel(selectedDay: selectedDay)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day cell — date number, stacked spanning bars, single-day dots
// ---------------------------------------------------------------------------

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.spanningTasks,
    required this.singleDayTasks,
    required this.primary,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final List<Task> spanningTasks;
  final List<Task> singleDayTasks;
  final Color primary;

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
                          : const Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        if (singleDayTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in singleDayTasks.take(3))
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: t.color,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ...spanningTasks.take(3).map(
              (t) => _BarSegment(task: t, day: day),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Spanning bar segment — adjacent same-color cells visually connect.
// ---------------------------------------------------------------------------

class _BarSegment extends StatelessWidget {
  const _BarSegment({required this.task, required this.day});

  final Task task;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final isStart = task.isStartDay(day);
    final isEnd = task.isEndDay(day);
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;

    final capLeft = isStart || isSunday;
    final capRight = isEnd || isSaturday;

    return Container(
      height: 6,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        color: task.color,
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
  const _DayHeader({required this.selectedDay});

  final DateTime selectedDay;

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
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${weekdays[selectedDay.weekday - 1]}, '
        '${months[selectedDay.month - 1]} ${selectedDay.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Text(
        _label(),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day panel — flat list of all tasks active on the selected day
// ---------------------------------------------------------------------------

class _DayPanel extends ConsumerWidget {
  const _DayPanel({required this.selectedDay});

  final DateTime selectedDay;

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

    // Multi-day tasks first, then single-day; both share the same tile.
    final sorted = [...tasks]
      ..sort((a, b) {
        if (a.isMultiDay != b.isMultiDay) return a.isMultiDay ? -1 : 1;
        return b.priority.index.compareTo(a.priority.index);
      });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final t = sorted[i];
        return _TaskTile(
          task: t,
          onToggle: () => ref.read(tasksProvider.notifier).toggle(t.id),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Task tile — works for both single-day and multi-day tasks
// ---------------------------------------------------------------------------

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onToggle});

  final Task task;
  final VoidCallback onToggle;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

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

  String? get _dateRangeLabel {
    if (!task.isMultiDay) return null;
    final s = task.startDate;
    final e = task.endDate!;
    return '${_months[s.month - 1]} ${s.day} – '
        '${_months[e.month - 1]} ${e.day}';
  }

  @override
  Widget build(BuildContext context) {
    final range = _dateRangeLabel;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: task.color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.completed
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFD0D0E0),
                    width: 2,
                  ),
                  color: task.completed
                      ? const Color(0xFF66BB6A)
                      : Colors.transparent,
                ),
                child: task.completed
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
                        color: task.completed
                            ? const Color(0xFF9090A8)
                            : const Color(0xFF1A1A2E),
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: const Color(0xFF9090A8),
                      ),
                    ),
                    if (range != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        range,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9090A8)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
