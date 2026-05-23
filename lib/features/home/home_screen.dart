import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../providers/home_provider.dart';
import '../../providers/tasks_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showAllOverdue = false;
  int _selectedTab = 0; // 0 = Current, 1 = Upcoming

  static const _maxCollapsedOverdue = 3;

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(todayProgressProvider);
    final overdue = ref.watch(overdueTasksProvider);
    final current = ref.watch(currentTasksProvider);
    final upcoming = ref.watch(upcomingTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _ProgressCard(progress: progress),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 16),
            _OverduePanel(
              overdue: overdue,
              expanded: _showAllOverdue,
              maxCollapsed: _maxCollapsedOverdue,
              onToggleExpanded: () =>
                  setState(() => _showAllOverdue = !_showAllOverdue),
            ),
          ],
          const SizedBox(height: 20),
          _SectionToggle(
            selected: _selectedTab,
            onChanged: (i) => setState(() => _selectedTab = i),
          ),
          const SizedBox(height: 12),
          if (_selectedTab == 0)
            _TaskList(
              tasks: current,
              emptyIcon: Icons.task_alt_outlined,
              emptyText: 'Nothing on today',
            )
          else
            _TaskList(
              tasks: upcoming,
              emptyIcon: Icons.event_outlined,
              emptyText: 'No upcoming tasks',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              const Expanded(
                child: Text(
                  "Today's progress",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
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
              backgroundColor: const Color(0xFFEDEDF5),
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasTasks
                ? '${progress.done} of ${progress.total} '
                    '${progress.total == 1 ? 'task' : 'tasks'} done'
                : 'No tasks for today',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B6B8A),
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
  });

  final List<Task> overdue;
  final bool expanded;
  final int maxCollapsed;
  final VoidCallback onToggleExpanded;

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
                onToggle: () =>
                    ref.read(tasksProvider.notifier).toggle(t.id),
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
  const _OverdueTile({required this.task, required this.onToggle});

  final Task task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: error, width: 4)),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Checkbox(completed: task.completed, color: error),
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
                        color: error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _overdueAgoLabel(task),
                      style: TextStyle(
                        fontSize: 12,
                        color: error.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                isMultiDay: task.isMultiDay,
                color: error,
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
        color: const Color(0xFFF0F0F7),
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
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
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
                  : const Color(0xFF6B6B8A),
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
    required this.emptyIcon,
    required this.emptyText,
  });

  final List<Task> tasks;
  final IconData emptyIcon;
  final String emptyText;

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

    return Column(
      children: [
        for (final t in tasks)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HomeTaskTile(
              task: t,
              onToggle: () =>
                  ref.read(tasksProvider.notifier).toggle(t.id),
            ),
          ),
      ],
    );
  }
}

class _HomeTaskTile extends StatelessWidget {
  const _HomeTaskTile({required this.task, required this.onToggle});

  final Task task;
  final VoidCallback onToggle;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String? get _dateRangeLabel {
    if (!task.isMultiDay) return null;
    final s = task.startDate;
    final e = task.endDate!;
    return '${_months[s.month - 1]} ${s.day} – '
        '${_months[e.month - 1]} ${e.day}';
  }

  String get _singleDateLabel {
    final s = task.startDate;
    return '${_months[s.month - 1]} ${s.day}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateRangeLabel ?? _singleDateLabel;

    return Container(
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
              _Checkbox(
                completed: task.completed,
                color: const Color(0xFF66BB6A),
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
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9090A8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                isMultiDay: task.isMultiDay,
                color: task.color,
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
          color: completed ? color : const Color(0xFFD0D0E0),
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
  const _StatusBadge({required this.isMultiDay, required this.color});

  final bool isMultiDay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = isMultiDay ? 'In Progress' : 'To-Do';
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
