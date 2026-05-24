import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_settings.dart';
import '../../models/task.dart';
import '../../providers/home_provider.dart';
import '../../providers/search_filter_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_format.dart';
import '../../shared/widgets/task_detail_sheet.dart';
import '../../shared/widgets/task_search_bar.dart';
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
  int _selectedTab = 0;
  bool _sortCurrent = true;
  bool _sortUpcoming = true;
  bool _sortOverdue = true;
  List<String>? _frozenCurrentIds;
  List<String>? _frozenUpcomingIds;
  List<String>? _frozenOverdueIds;

  /// Drag-to-reorder is opt-in per section so accidental drags don't shuffle
  /// the auto-sorted list.
  bool _reorderCurrent = false;
  bool _reorderUpcoming = false;

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

  List<Task> _displayCurrent(List<Task> raw, DateTime today) {
    if (_reorderCurrent) {
      return [...raw]..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    }
    return applyHomeDisplayOrder(
      tasks: raw,
      sortEnabled: _sortCurrent,
      frozenIds: _frozenCurrentIds,
      comparator: (a, b) => compareCurrentTasks(a, b, today),
    );
  }

  List<Task> _displayUpcoming(List<Task> raw, DateTime today) {
    if (_reorderUpcoming) {
      return [...raw]..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    }
    return applyHomeDisplayOrder(
      tasks: raw,
      sortEnabled: _sortUpcoming,
      frozenIds: _frozenUpcomingIds,
      comparator: (a, b) => compareUpcomingTasks(a, b, today),
    );
  }

  List<Task> _displayOverdue(List<Task> raw) => applyHomeDisplayOrder(
        tasks: raw,
        sortEnabled: _sortOverdue,
        frozenIds: _frozenOverdueIds,
        comparator: compareOverdueTasks,
      );

  void _freezeAndToggleCurrent(
      Task task, List<Task> displayed, DateTime today) {
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
    if (task.isRecurring) {
      final day = task.actionDayForRow(today, inUpcomingSection: true);
      ref.read(tasksProvider.notifier).toggleForDay(task.id, day);
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

  Future<void> _handleTapTask(Task task, DateTime today) async {
    final selection = ref.read(selectionProvider);
    if (selection.active) {
      ref.read(selectionProvider.notifier).toggle(task.id);
      return;
    }
    await showTaskDetailSheet(
      context,
      taskId: task.id,
      referenceDay: today,
      onDelete: () => _deleteWithUndo(task),
    );
  }

  Future<void> _deleteWithUndo(Task task) async {
    final removed = await ref.read(tasksProvider.notifier).remove(task.id);
    if (removed == null) return;
    if (!mounted) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted "${removed.title}"'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(tasksProvider.notifier).restore(removed),
        ),
      ),
    );
  }

  void _onReorderCurrent(List<Task> displayed, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [...displayed];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    unawaited(ref
        .read(tasksProvider.notifier)
        .reorder(list.map((t) => t.id).toList()));
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
    final filter = ref.watch(taskFilterProvider);

    final filteredOverdue = filter.apply(rawOverdue, today);
    final filteredCurrent = filter.apply(rawCurrent, today);
    final filteredUpcoming = filter.apply(rawUpcoming, today);

    final overdue = _displayOverdue(filteredOverdue);
    final current = _displayCurrent(filteredCurrent, today);
    final upcoming = _displayUpcoming(filteredUpcoming, today);

    final settings = ref.watch(resolvedSettingsProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);
    final showProgress = settings.showProgressCard && !filter.isActive;
    final showOverdue = settings.showOverduePanel;
    final showToggle = settings.showSectionToggle;
    final showCurrentList = !showToggle || _selectedTab == 0;

    final searchOpen = ref.watch(searchBarOpenProvider);
    final selection = ref.watch(selectionProvider);

    return Scaffold(
      appBar: selection.active
          ? _SelectionAppBar(
              selection: selection,
              onCancel: () => ref.read(selectionProvider.notifier).exit(),
              onComplete: () async {
                await ref
                    .read(tasksProvider.notifier)
                    .bulkComplete(selection.ids, today);
                ref.read(selectionProvider.notifier).exit();
              },
              onDelete: () async {
                final removed = await ref
                    .read(tasksProvider.notifier)
                    .bulkDelete(selection.ids);
                ref.read(selectionProvider.notifier).exit();
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        'Deleted ${removed.length} ${removed.length == 1 ? 'task' : 'tasks'}'),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        for (final t in removed) {
                          ref.read(tasksProvider.notifier).restore(t);
                        }
                      },
                    ),
                  ),
                );
              },
              onChangeQuadrant: (q) async {
                await ref
                    .read(tasksProvider.notifier)
                    .bulkMoveQuadrant(selection.ids, q);
                ref.read(selectionProvider.notifier).exit();
              },
            )
          : AppBar(
              title: const Text('Home'),
              actions: [
                IconButton(
                  tooltip: 'Search',
                  icon: Icon(filter.isActive || searchOpen
                      ? Icons.filter_alt
                      : Icons.search),
                  onPressed: () => ref
                      .read(searchBarOpenProvider.notifier)
                      .state = !searchOpen,
                ),
                PopupMenuButton<_HomeAction>(
                  tooltip: 'More',
                  onSelected: (a) => _handleAction(a),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _HomeAction.toggleReorderCurrent,
                      child: Row(
                        children: [
                          Icon(_reorderCurrent ? Icons.check : Icons.swap_vert,
                              size: 18),
                          const SizedBox(width: 10),
                          Text(_reorderCurrent
                              ? 'Reorder: ON (current)'
                              : 'Reorder current'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _HomeAction.toggleReorderUpcoming,
                      child: Row(
                        children: [
                          Icon(_reorderUpcoming ? Icons.check : Icons.swap_vert,
                              size: 18),
                          const SizedBox(width: 10),
                          Text(_reorderUpcoming
                              ? 'Reorder: ON (upcoming)'
                              : 'Reorder upcoming'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: _HomeAction.selectMode,
                      child: Row(
                        children: [
                          Icon(Icons.check_box_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Select tasks'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          if (searchOpen) const TaskSearchBar(),
          Expanded(
            child: ListView(
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
                    onOpen: (task) => _handleTapTask(task, today),
                    onLongPress: (task) =>
                        showAddItemSheet(context, taskToEdit: task),
                    selectionIds: selection.active ? selection.ids : null,
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
                    emptyText: filter.isActive
                        ? 'No tasks match your filter'
                        : 'Nothing on today',
                    onToggleTask: (task) =>
                        _freezeAndToggleCurrent(task, current, today),
                    onOpen: (task) => _handleTapTask(task, today),
                    onLongPress: (task) =>
                        showAddItemSheet(context, taskToEdit: task),
                    reorderable: _reorderCurrent,
                    onReorder: (a, b) => _onReorderCurrent(current, a, b),
                    selectionIds: selection.active ? selection.ids : null,
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
                    emptyText: filter.isActive
                        ? 'No upcoming tasks match your filter'
                        : 'No upcoming tasks',
                    onToggleTask: (task) =>
                        _freezeAndToggleUpcoming(task, upcoming, today),
                    onOpen: (task) => _handleTapTask(task, today),
                    onLongPress: (task) =>
                        showAddItemSheet(context, taskToEdit: task),
                    reorderable: _reorderUpcoming,
                    onReorder: (a, b) => _onReorderCurrent(upcoming, a, b),
                    selectionIds: selection.active ? selection.ids : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(_HomeAction action) {
    switch (action) {
      case _HomeAction.toggleReorderCurrent:
        setState(() {
          _reorderCurrent = !_reorderCurrent;
          if (_reorderCurrent) _sortCurrent = false;
        });
        break;
      case _HomeAction.toggleReorderUpcoming:
        setState(() {
          _reorderUpcoming = !_reorderUpcoming;
          if (_reorderUpcoming) _sortUpcoming = false;
        });
        break;
      case _HomeAction.selectMode:
        ref.read(selectionProvider.notifier).enter();
        break;
    }
  }
}

enum _HomeAction { toggleReorderCurrent, toggleReorderUpcoming, selectMode }

// ---------------------------------------------------------------------------
// Multi-select app bar
// ---------------------------------------------------------------------------

class _SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SelectionAppBar({
    required this.selection,
    required this.onCancel,
    required this.onComplete,
    required this.onDelete,
    required this.onChangeQuadrant,
  });

  final SelectionState selection;
  final VoidCallback onCancel;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final ValueChanged<MatrixQuadrant> onChangeQuadrant;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onCancel,
        tooltip: 'Exit selection',
      ),
      title: Text(
          '${selection.count} ${selection.count == 1 ? 'selected' : 'selected'}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: selection.count == 0 ? null : onComplete,
          tooltip: 'Mark complete',
        ),
        PopupMenuButton<MatrixQuadrant>(
          icon: const Icon(Icons.dashboard_outlined),
          tooltip: 'Move to quadrant',
          onSelected: onChangeQuadrant,
          itemBuilder: (_) => [
            for (final q in MatrixQuadrant.values)
              PopupMenuItem(
                value: q,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration:
                          BoxDecoration(color: q.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(q.label),
                  ],
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: selection.count == 0 ? null : onDelete,
          tooltip: 'Delete',
        ),
      ],
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
    required this.onOpen,
    required this.onLongPress,
    required this.selectionIds,
  });

  final List<Task> overdue;
  final bool expanded;
  final int maxCollapsed;
  final VoidCallback onToggleExpanded;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onLongPress;
  final Set<String>? selectionIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    final visible = expanded ? overdue : overdue.take(maxCollapsed).toList();
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
                onOpen: () => onOpen(t),
                onLongPress: () => onLongPress(t),
                selected: selectionIds?.contains(t.id) ?? false,
                selectionActive: selectionIds != null,
              ),
            ),
          if (hiddenCount > 0 || expanded) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onToggleExpanded,
                style: TextButton.styleFrom(
                  foregroundColor: error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
  const _OverdueTile({
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onLongPress,
    required this.selected,
    required this.selectionActive,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final bool selected;
  final bool selectionActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final done = task.completed;
    final statusColor = done ? AppSemanticColors.successGreen : error;

    return Container(
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: selectionActive ? onOpen : onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: selectionActive
                    ? _Checkbox(
                        completed: selected, color: theme.colorScheme.primary)
                    : _Checkbox(completed: done, color: statusColor),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
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
              ),
            ),
            _StatusBadge(
              isMultiDay: task.isMultiDay,
              isRecurring: task.isRecurring,
              hasSubtasks: task.hasSubtasks,
              subtasksDone: task.completedSubtaskCount,
              subtasksTotal: task.subtasks.length,
              color: statusColor,
            ),
          ],
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
// Task list — supports drag-to-reorder and selection mode
// ---------------------------------------------------------------------------

class _TaskList extends ConsumerWidget {
  const _TaskList({
    required this.tasks,
    required this.referenceDay,
    required this.density,
    required this.dateFormat,
    required this.quadrantColors,
    required this.onToggleTask,
    required this.onOpen,
    required this.onLongPress,
    this.upcoming = false,
    required this.emptyIcon,
    required this.emptyText,
    required this.reorderable,
    required this.onReorder,
    required this.selectionIds,
  });

  final List<Task> tasks;
  final DateTime referenceDay;
  final DensityPref density;
  final DateFormatPref dateFormat;
  final Map<MatrixQuadrant, Color> quadrantColors;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onLongPress;
  final bool upcoming;
  final IconData emptyIcon;
  final String emptyText;
  final bool reorderable;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Set<String>? selectionIds;

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

    if (reorderable) {
      return ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: true,
        itemCount: tasks.length,
        // ignore: deprecated_member_use
        onReorder: onReorder,
        itemBuilder: (context, i) {
          final t = tasks[i];
          return Padding(
            key: ValueKey(t.id),
            padding: EdgeInsets.only(bottom: gap),
            child: _HomeTaskTile(
              task: t,
              referenceDay: _today,
              upcoming: upcoming,
              density: density,
              dateFormat: dateFormat,
              accentColor: quadrantColors[t.quadrant] ?? t.color,
              onToggle: () => onToggleTask(t),
              onOpen: () => onOpen(t),
              onLongPress: () => onLongPress(t),
              reorderable: true,
              selected: selectionIds?.contains(t.id) ?? false,
              selectionActive: selectionIds != null,
            ),
          );
        },
      );
    }

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
              onOpen: () => onOpen(t),
              onLongPress: () => onLongPress(t),
              reorderable: false,
              selected: selectionIds?.contains(t.id) ?? false,
              selectionActive: selectionIds != null,
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
    required this.onOpen,
    required this.onLongPress,
    this.upcoming = false,
    required this.reorderable,
    required this.selected,
    required this.selectionActive,
  });

  final Task task;
  final DateTime referenceDay;
  final VoidCallback onToggle;
  final DensityPref density;
  final DateFormatPref dateFormat;
  final Color accentColor;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final bool upcoming;
  final bool reorderable;
  final bool selected;
  final bool selectionActive;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  bool get _isDone =>
      task.isRowDoneOnDate(referenceDay, inUpcomingSection: upcoming);

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
    final base = formatDate(task.startDate, dateFormat);
    if (task.startTime != null) {
      return '$base · ${task.startTime!.formatTwelveHour()}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final showCheckbox = !task.isEvent || !upcoming;
    final m = density.paddingMultiplier;
    final hPad = 14 * m;
    final vPad = 12 * m;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : AppSemanticColors.tileBackground(context),
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
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap:
                  selectionActive ? onOpen : (showCheckbox ? onToggle : onOpen),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: selectionActive
                    ? _Checkbox(
                        completed: selected,
                        color: theme.colorScheme.primary,
                      )
                    : (showCheckbox
                        ? _Checkbox(
                            completed: _isDone,
                            color: AppSemanticColors.successGreen,
                          )
                        : Icon(Icons.event, size: 22, color: accentColor)),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
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
              ),
            ),
            if (!task.isEvent) ...[
              const SizedBox(width: 4),
              _StatusBadge(
                isMultiDay: task.isMultiDay,
                isRecurring: task.isRecurring,
                hasSubtasks: task.hasSubtasks,
                subtasksDone: task.completedSubtaskCount,
                subtasksTotal: task.subtasks.length,
                color: accentColor,
              ),
            ],
            if (reorderable) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.drag_indicator,
                size: 18,
                color: AppSemanticColors.textFaint(context),
              ),
            ],
          ],
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
    required this.hasSubtasks,
    required this.subtasksDone,
    required this.subtasksTotal,
    required this.color,
  });

  final bool isMultiDay;
  final bool isRecurring;
  final bool hasSubtasks;
  final int subtasksDone;
  final int subtasksTotal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSubtasks)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_box_outlined, size: 10, color: color),
                  const SizedBox(width: 3),
                  Text(
                    '$subtasksDone/$subtasksTotal',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isRecurring ? 'Repeats' : (isMultiDay ? 'In Progress' : 'To-Do'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}
