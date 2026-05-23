import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_settings.dart';
import '../../models/task.dart';
import '../../providers/home_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_format.dart';
import '../../theme/app_theme.dart';
import '../calendar/add_item_sheet.dart';
import 'home_task_sort.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showAllOverdue = false;
  int _selectedTab = 0; // 0 = Current, 1 = Upcoming
  bool _sortCurrent = true;
  bool _sortUpcoming = true;
  bool _sortOverdue = true;
  List<String>? _frozenCurrentIds;
  List<String>? _frozenUpcomingIds;
  List<String>? _frozenOverdueIds;

  static const _maxCollapsedOverdue = 3;

  void _enableAllSorting() {
    _sortCurrent = true;
    _sortUpcoming = true;
    _sortOverdue = true;
    _frozenCurrentIds = null;
    _frozenUpcomingIds = null;
    _frozenOverdueIds = null;
  }

  void _onTabChanged(int index) {
    if (index == _selectedTab) return;
    setState(() {
      if (_selectedTab == 0) {
        _sortCurrent = true;
        _frozenCurrentIds = null;
      } else {
        _sortUpcoming = true;
        _frozenUpcomingIds = null;
      }
      _sortOverdue = true;
      _frozenOverdueIds = null;
      _selectedTab = index;
    });
  }

  List<Task> _displayCurrent(List<Task> raw, DateTime today) =>
      applyHomeDisplayOrder(
        tasks: raw,
        sortEnabled: _sortCurrent,
        frozenIds: _frozenCurrentIds,
        comparator: (a, b) => compareCurrentTasks(a, b, today),
      );

  List<Task> _displayUpcoming(List<Task> raw, DateTime today) =>
      applyHomeDisplayOrder(
        tasks: raw,
        sortEnabled: _sortUpcoming,
        frozenIds: _frozenUpcomingIds,
        comparator: (a, b) => compareUpcomingTasks(a, b, today),
      );

  List<Task> _displayOverdue(List<Task> raw) => applyHomeDisplayOrder(
        tasks: raw,
        sortEnabled: _sortOverdue,
        frozenIds: _frozenOverdueIds,
        comparator: compareOverdueTasks,
      );

  void _freezeAndToggleCurrent(Task task, List<Task> displayed, DateTime today) {
    setState(() {
      _frozenCurrentIds = displayed.map((t) => t.id).toList();
      _sortCurrent = false;
    });
    ref.read(tasksProvider.notifier).toggleForDay(task.id, today);
  }

  void _freezeAndToggleUpcoming(
      Task task, List<Task> displayed, DateTime today) {
    setState(() {
      _frozenUpcomingIds = displayed.map((t) => t.id).toList();
      _sortUpcoming = false;
    });
    // Recurring tasks: toggle the actual next occurrence day, not today.
    // Non-recurring future tasks: flip completed globally via toggle().
    if (task.isRecurring) {
      final nextDay = task.nextOccurrenceAfter(today);
      if (nextDay != null) {
        ref.read(tasksProvider.notifier).toggleForDay(task.id, nextDay);
      }
    } else {
      ref.read(tasksProvider.notifier).toggle(task.id);
    }
  }

  void _freezeAndToggleOverdue(Task task, List<Task> displayed) {
    setState(() {
      _frozenOverdueIds = displayed.map((t) => t.id).toList();
      _sortOverdue = false;
    });
    ref.read(tasksProvider.notifier).toggle(task.id);
  }

  @override
  void reassemble() {
    super.reassemble();
    _enableAllSorting();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(homeRevisitSignalProvider, (previous, next) {
      if (previous == next) return;
      setState(_enableAllSorting);
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final progress = ref.watch(todayProgressProvider);
    final rawOverdue = ref.watch(overdueTasksProvider);
    final rawCurrent = ref.watch(currentTasksProvider);
    final rawUpcoming = ref.watch(upcomingTasksProvider);
    final overdue = _displayOverdue(rawOverdue);
    final current = _displayCurrent(rawCurrent, today);
    final upcoming = _displayUpcoming(rawUpcoming, today);

    final settings = ref.watch(resolvedSettingsProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);
    final showProgress = settings.showProgressCard;
    final showOverdue = settings.showOverduePanel;
    final showToggle = settings.showSectionToggle;
    final showCurrentList = !showToggle || _selectedTab == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (showProgress) _ProgressCard(progress: progress),
          if (showOverdue && overdue.isNotEmpty) ...[
            if (showProgress) const SizedBox(height: 16),
            _OverduePanel(
              overdue: overdue,
              expanded: _showAllOverdue,
              maxCollapsed: _maxCollapsedOverdue,
              onToggleExpanded: () =>
                  setState(() => _showAllOverdue = !_showAllOverdue),
              onToggleTask: (task) =>
                  _freezeAndToggleOverdue(task, overdue),
              onEditTask: (task) =>
                  showAddItemSheet(context, taskToEdit: task),
            ),
          ],
          if (showProgress ||
              (showOverdue && overdue.isNotEmpty) ||
              showToggle)
            const SizedBox(height: 20),
          if (showToggle) ...[
            _SectionToggle(
              selected: _selectedTab,
              onChanged: _onTabChanged,
            ),
            const SizedBox(height: 12),
          ],
          if (showCurrentList)
            _TaskList(
              tasks: current,
              referenceDay: today,
              density: settings.density,
              dateFormat: settings.dateFormat,
              quadrantColors: quadrantColors,
              emptyIcon: Icons.task_alt_outlined,
              emptyText: 'Nothing on today',
              onToggleTask: (task) =>
                  _freezeAndToggleCurrent(task, current, today),
              onEditTask: (task) =>
                  showAddItemSheet(context, taskToEdit: task),
            )
          else
            _TaskList(
              tasks: upcoming,
              referenceDay: today,
              upcoming: true,
              density: settings.density,
              dateFormat: settings.dateFormat,
              quadrantColors: quadrantColors,
              emptyIcon: Icons.event_outlined,
              emptyText: 'No upcoming tasks',
              onToggleTask: (task) =>
                  _freezeAndToggleUpcoming(task, upcoming, today),
              onEditTask: (task) =>
                  showAddItemSheet(context, taskToEdit: task),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final TodayProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final hasTasks = progress.total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppSemanticColors.tileBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.softShadow(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's progress",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
              ),
              Text(
                hasTasks ? '${progress.percent}%' : '--',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: hasTasks ? progress.fraction : 0,
              minHeight: 8,
              backgroundColor: AppSemanticColors.trackBackground(context),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasTasks
                ? '${progress.done} of ${progress.total} '
                    '${progress.total == 1 ? 'task' : 'tasks'} done'
                : 'No tasks for today',
            style: TextStyle(
              fontSize: 13,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overdue panel
// ---------------------------------------------------------------------------

class _OverduePanel extends ConsumerWidget {
  const _OverduePanel({
    required this.overdue,
    required this.expanded,
    required this.maxCollapsed,
    required this.onToggleExpanded,
    required this.onToggleTask,
    required this.onEditTask,
  });

  final List<Task> overdue;
  final bool expanded;
  final int maxCollapsed;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<Task> onEditTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    final visible =
        expanded ? overdue : overdue.take(maxCollapsed).toList();
    final hiddenCount = overdue.length - visible.length;

    return Container(
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: error),
              const SizedBox(width: 8),
              Text(
                'Overdue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: error,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${overdue.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: error.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final t in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OverdueTile(
                task: t,
                onToggle: () => onToggleTask(t),
                onEdit: () => onEditTask(t),
              ),
            ),
          if (hiddenCount > 0 || expanded) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggleExpanded,
                style: TextButton.styleFrom(
                  foregroundColor: error,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  expanded ? 'Show less' : 'View all ($hiddenCount more)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _OverdueTile extends StatelessWidget {
  const _OverdueTile({required this.task, required this.onToggle, required this.onEdit});

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final done = task.completed;
    final statusColor =
        done ? AppSemanticColors.successGreen : error;

    return Container(
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: InkWell(
        onTap: onToggle,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Checkbox(completed: done, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: done
                            ? AppSemanticColors.textFaint(context)
                            : error,
                        decoration: done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppSemanticColors.textFaint(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done
                          ? 'Resolved  ·  ${_overdueAgoLabel(task)}'
                          : _overdueAgoLabel(task),
                      style: TextStyle(
                        fontSize: 12,
                        color: done
                            ? AppSemanticColors.textFaint(context)
                            : error.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                isMultiDay: task.isMultiDay,
                isRecurring: task.isRecurring,
                color: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _overdueAgoLabel(Task task) {
    final deadline = task.endDate ?? task.startDate;
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysAgo = today.difference(d).inDays;
    if (daysAgo <= 0) return 'Due today';
    if (daysAgo == 1) return 'Overdue by 1 day';
    return 'Overdue by $daysAgo days';
  }
}

// ---------------------------------------------------------------------------
// Section toggle (Current / Upcoming)
// ---------------------------------------------------------------------------

class _SectionToggle extends StatelessWidget {
  const _SectionToggle({
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppSemanticColors.subtleSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Current task',
            selected: selected == 0,
            onTap: () => onChanged(0),
          ),
          _ToggleButton(
            label: 'Upcoming task',
            selected: selected == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppSemanticColors.tileBackground(context)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppSemanticColors.softShadow(context),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? theme.colorScheme.primary
                  : AppSemanticColors.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task list (used for Current / Upcoming)
// ---------------------------------------------------------------------------

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.tasks,
    required this.referenceDay,
    required this.density,
    required this.dateFormat,
    required this.quadrantColors,
    required this.onToggleTask,
    required this.onEditTask,
    this.upcoming = false,
    required this.emptyIcon,
    required this.emptyText,
  });

  final List<Task> tasks;
  final DateTime referenceDay;
  final DensityPref density;
  final DateFormatPref dateFormat;
  final Map<MatrixQuadrant, Color> quadrantColors;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<Task> onEditTask;
  final bool upcoming;
  final IconData emptyIcon;
  final String emptyText;

  DateTime get _today {
    final n = referenceDay;
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 44, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text(
                emptyText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final gap = (8 * density.paddingMultiplier).round().toDouble();

    return Column(
      children: [
        for (final t in tasks)
          Padding(
              padding: EdgeInsets.only(bottom: gap),
              child: _HomeTaskTile(
                task: t,
                referenceDay: _today,
                upcoming: upcoming,
                density: density,
                dateFormat: dateFormat,
                accentColor: quadrantColors[t.quadrant] ?? t.color,
                onToggle: () => onToggleTask(t),
                onEdit: () => onEditTask(t),
              ),
            ),
      ],
    );
  }
}

class _HomeTaskTile extends StatelessWidget {
  const _HomeTaskTile({
    required this.task,
    required this.referenceDay,
    required this.onToggle,
    required this.density,
    required this.dateFormat,
    required this.accentColor,
    required this.onEdit,
    this.upcoming = false,
  });

  final Task task;
  final DateTime referenceDay;
  final VoidCallback onToggle;
  final DensityPref density;
  final DateFormatPref dateFormat;
  final Color accentColor;
  final VoidCallback onEdit;
  final bool upcoming;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool get _isDone => task.isCompletedOn(referenceDay);

  String get _dateLabel {
    if (upcoming && task.isRecurring) {
      final next = task.nextOccurrenceAfter(referenceDay)!;
      return 'Next: ${formatDate(next, dateFormat)}';
    }
    if (task.isMultiDay) {
      return formatDateRange(task.startDate, task.endDate!, dateFormat);
    }
    if (task.isRecurring) {
      final days = (task.recurrence!.weekdays.toList()..sort())
          .map((w) => _weekdayShort[w - 1])
          .join(' ');
      return 'Repeats $days';
    }
    return formatDate(task.startDate, dateFormat);
  }

  @override
  Widget build(BuildContext context) {
    final showCheckbox = !task.isEvent || !upcoming;
    final m = density.paddingMultiplier;
    final hPad = 14 * m;
    final vPad = 12 * m;

    return Container(
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
        onTap: showCheckbox ? onToggle : null,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showCheckbox)
                _Checkbox(
                  completed: _isDone,
                  color: AppSemanticColors.successGreen,
                )
              else
                Icon(Icons.event, size: 22, color: accentColor),
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
                        color: _isDone
                            ? AppSemanticColors.textFaint(context)
                            : AppSemanticColors.textStrong(context),
                        decoration: _isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: AppSemanticColors.textFaint(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppSemanticColors.textFaint(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!task.isEvent)
                _StatusBadge(
                  isMultiDay: task.isMultiDay,
                  isRecurring: task.isRecurring,
                  color: accentColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.completed, required this.color});

  final bool completed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: completed ? color : AppSemanticColors.subtleBorder(context),
          width: 2,
        ),
        color: completed ? color : Colors.transparent,
      ),
      child: completed
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isMultiDay,
    required this.isRecurring,
    required this.color,
  });

  final bool isMultiDay;
  final bool isRecurring;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label =
        isRecurring ? 'Repeats' : (isMultiDay ? 'In Progress' : 'To-Do');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
