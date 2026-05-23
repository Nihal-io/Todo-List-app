import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_settings.dart';
import '../../models/task.dart';
import '../../providers/clock_provider.dart';
import '../../providers/matrix_provider.dart';
import '../../providers/search_filter_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/widgets/task_detail_sheet.dart';
import '../../shared/widgets/task_search_bar.dart';
import '../../theme/app_theme.dart';
import '../calendar/add_item_sheet.dart';

class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  /// Per-quadrant snapshot of displayed task ids. When set, the panel
  /// renders in this fixed order — items don't reshuffle on completion
  /// and recently-completed tasks remain visible (crossed off) until the
  /// user revisits the tab and the snapshot is cleared.
  final Map<MatrixQuadrant, List<String>> _frozen = {};

  void _clearFrozen() => _frozen.clear();

  @override
  void reassemble() {
    super.reassemble();
    setState(_clearFrozen);
  }

  List<Task> _displayQuadrant(
    MatrixQuadrant q,
    Map<MatrixQuadrant, List<Task>> liveOpen,
    Map<String, Task> byId,
  ) {
    final frozen = _frozen[q];
    if (frozen == null) {
      return liveOpen[q] ?? const <Task>[];
    }

    final out = <Task>[];
    final seen = <String>{};
    for (final id in frozen) {
      final t = byId[id];
      if (t == null) continue;
      if (t.quadrant != q) continue;
      out.add(t);
      seen.add(id);
    }
    for (final t in liveOpen[q] ?? const <Task>[]) {
      if (seen.add(t.id)) out.add(t);
    }
    return out;
  }

  void _onTileToggle(
    MatrixQuadrant q,
    Task task,
    List<Task> displayed,
    DateTime today,
  ) {
    setState(() {
      _frozen[q] = displayed.map((t) => t.id).toList(growable: false);
    });
    ref.read(tasksProvider.notifier).toggleForDay(task.id, today);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(matrixRevisitSignalProvider, (prev, next) {
      if (prev == next) return;
      setState(_clearFrozen);
    });

    final settings = ref.watch(resolvedSettingsProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);
    final today = ref.watch(todayProvider);
    final liveOpen = ref.watch(matrixItemsProvider);
    final openCount = ref.watch(gridOpenCountProvider);
    final overdueCount = ref.watch(gridOverdueCountProvider);
    final allTasks = ref.watch(tasksListProvider);
    final byId = {for (final t in allTasks) t.id: t};
    final density = settings.density.paddingMultiplier;
    final filter = ref.watch(taskFilterProvider);
    final searchOpen = ref.watch(searchBarOpenProvider);

    Widget cell(MatrixQuadrant q) {
      var tasks = _displayQuadrant(q, liveOpen, byId);
      if (filter.isActive) tasks = filter.apply(tasks, today);
      final color = quadrantColors[q] ?? q.color;
      return _QuadrantSection(
        quadrant: q,
        color: color,
        tasks: tasks,
        today: today,
        density: density,
        showOverdueHighlight: settings.showGridOverdueHighlight,
        showUrgencyBadges: settings.showGridUrgencyBadges,
        soonThresholdDays: settings.gridSoonThreshold.days,
        onToggle: (task) => _onTileToggle(q, task, tasks, today),
        onOpen: (task) => showTaskDetailSheet(
          context,
          taskId: task.id,
          referenceDay: today,
        ),
        onLongPress: (task) => showAddItemSheet(context, taskToEdit: task),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grid View'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: Icon(filter.isActive || searchOpen
                ? Icons.filter_alt
                : Icons.search),
            onPressed: () =>
                ref.read(searchBarOpenProvider.notifier).state = !searchOpen,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _GridSummaryBar(
            openCount: openCount,
            overdueCount: overdueCount,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(12, 4, 12, 100 * density.clamp(0.8, 1.0)),
        child: Column(
          children: [
            if (searchOpen) const TaskSearchBar(),
            if (settings.showGridAxisLabels) ...[
              const _TopAxisLabels(),
              SizedBox(height: 6 * density),
            ],
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (settings.showGridAxisLabels) ...[
                    const _SideAxisLabels(),
                    SizedBox(width: 6 * density),
                  ],
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: cell(MatrixQuadrant.schedule)),
                              SizedBox(width: 8 * density),
                              Expanded(child: cell(MatrixQuadrant.doFirst)),
                            ],
                          ),
                        ),
                        SizedBox(height: 8 * density),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: cell(MatrixQuadrant.eliminate)),
                              SizedBox(width: 8 * density),
                              Expanded(child: cell(MatrixQuadrant.delegate)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary bar
// ---------------------------------------------------------------------------

class _GridSummaryBar extends StatelessWidget {
  const _GridSummaryBar({
    required this.openCount,
    required this.overdueCount,
  });

  final int openCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded, size: 16, color: primary),
          const SizedBox(width: 8),
          Text(
            openCount == 0
                ? 'No open items'
                : '$openCount open ${openCount == 1 ? 'item' : 'items'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
          if (overdueCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppSemanticColors.dangerRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppSemanticColors.dangerRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$overdueCount overdue',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppSemanticColors.dangerRed,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Auto-sorted by urgency',
            style: TextStyle(
              fontSize: 11,
              color: AppSemanticColors.textFaint(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Axis labels
// ---------------------------------------------------------------------------

class _TopAxisLabels extends StatelessWidget {
  const _TopAxisLabels();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 22),
      child: Row(
        children: [
          Expanded(child: _AxisText('NOT URGENT')),
          SizedBox(width: 8),
          Expanded(child: _AxisText('URGENT')),
        ],
      ),
    );
  }
}

class _SideAxisLabels extends StatelessWidget {
  const _SideAxisLabels();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      child: Column(
        children: [
          Expanded(
            child: Center(child: _RotatedAxisText('IMPORTANT')),
          ),
          SizedBox(height: 8),
          Expanded(
            child: Center(child: _RotatedAxisText('NOT IMPORTANT')),
          ),
        ],
      ),
    );
  }
}

class _AxisText extends StatelessWidget {
  const _AxisText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: AppSemanticColors.textFaint(context),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _RotatedAxisText extends StatelessWidget {
  const _RotatedAxisText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: AppSemanticColors.textFaint(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quadrant section
// ---------------------------------------------------------------------------

class _QuadrantSection extends StatelessWidget {
  const _QuadrantSection({
    required this.quadrant,
    required this.color,
    required this.tasks,
    required this.today,
    required this.density,
    required this.showOverdueHighlight,
    required this.showUrgencyBadges,
    required this.soonThresholdDays,
    required this.onToggle,
    required this.onOpen,
    required this.onLongPress,
  });

  final MatrixQuadrant quadrant;
  final Color color;
  final List<Task> tasks;
  final DateTime today;
  final double density;
  final bool showOverdueHighlight;
  final bool showUrgencyBadges;
  final int soonThresholdDays;
  final ValueChanged<Task> onToggle;
  final ValueChanged<Task> onOpen;
  final ValueChanged<Task> onLongPress;

  @override
  Widget build(BuildContext context) {
    final surface = AppSemanticColors.tileBackground(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.softShadow(context),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QuadrantHeader(
              quadrant: quadrant, color: color, count: tasks.length),
          Expanded(
            child: tasks.isEmpty
                ? _EmptyQuadrant(quadrant: quadrant, color: color)
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      8 * density,
                      0,
                      8 * density,
                      8 * density,
                    ),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6 * density),
                    itemBuilder: (context, i) {
                      final task = tasks[i];
                      return _GridTaskTile(
                        task: task,
                        accentColor: color,
                        today: today,
                        density: density,
                        showOverdueHighlight: showOverdueHighlight,
                        showUrgencyBadges: showUrgencyBadges,
                        soonThresholdDays: soonThresholdDays,
                        onToggle: () => onToggle(task),
                        onOpen: () => onOpen(task),
                        onLongPress: () => onLongPress(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuadrantHeader extends StatelessWidget {
  const _QuadrantHeader({
    required this.quadrant,
    required this.color,
    required this.count,
  });

  final MatrixQuadrant quadrant;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                quadrant.label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyQuadrant extends StatelessWidget {
  const _EmptyQuadrant({required this.quadrant, required this.color});

  final MatrixQuadrant quadrant;
  final Color color;

  static const _prompts = {
    MatrixQuadrant.doFirst: 'No fires to put out',
    MatrixQuadrant.schedule: 'Nothing to plan',
    MatrixQuadrant.delegate: 'Nothing to hand off',
    MatrixQuadrant.eliminate: 'Inbox zero',
  };

  static const _icons = {
    MatrixQuadrant.doFirst: Icons.local_fire_department_outlined,
    MatrixQuadrant.schedule: Icons.event_available_outlined,
    MatrixQuadrant.delegate: Icons.forward_to_inbox_outlined,
    MatrixQuadrant.eliminate: Icons.cleaning_services_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icons[quadrant] ?? Icons.check_circle_outline,
              size: 28,
              color: color.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 6),
            Text(
              _prompts[quadrant] ?? 'All clear',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppSemanticColors.textFaint(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _GridTaskTile extends StatelessWidget {
  const _GridTaskTile({
    required this.task,
    required this.accentColor,
    required this.today,
    required this.density,
    required this.showOverdueHighlight,
    required this.showUrgencyBadges,
    required this.soonThresholdDays,
    required this.onToggle,
    required this.onOpen,
    required this.onLongPress,
  });

  final Task task;
  final Color accentColor;
  final DateTime today;
  final double density;
  final bool showOverdueHighlight;
  final bool showUrgencyBadges;
  final int soonThresholdDays;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  bool get _isCompleted {
    if (task.isEvent) return false;
    return task.isCompletedOn(today);
  }

  bool get _isOverdue {
    if (_isCompleted) return false;
    return matrixUrgencyScore(task, today) < 0;
  }

  @override
  Widget build(BuildContext context) {
    final highlightOverdue = showOverdueHighlight && _isOverdue;
    final urgency = showUrgencyBadges
        ? _UrgencyLabel.forTask(
            task,
            today,
            isCompleted: _isCompleted,
            soonThresholdDays: soonThresholdDays,
          )
        : null;

    final tileColor = highlightOverdue
        ? AppSemanticColors.dangerRed.withValues(alpha: 0.08)
        : AppSemanticColors.subtleSurface(context);

    final tileBorder = highlightOverdue
        ? Border(
            left: BorderSide(color: accentColor, width: 3),
            top: BorderSide(
              color: AppSemanticColors.dangerRed.withValues(alpha: 0.35),
            ),
            right: BorderSide(
              color: AppSemanticColors.dangerRed.withValues(alpha: 0.35),
            ),
            bottom: BorderSide(
              color: AppSemanticColors.dangerRed.withValues(alpha: 0.35),
            ),
          )
        : Border(left: BorderSide(color: accentColor, width: 3));

    final titleColor = _isCompleted
        ? AppSemanticColors.textFaint(context)
        : AppSemanticColors.textStrong(context);

    final vPad = 7.0 * density;
    final hPad = 8.0 * density;

    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        border: tileBorder,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: task.isEvent ? onOpen : onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(right: 8 * density),
                child: task.isEvent
                    ? Icon(Icons.event, size: 16 * density, color: accentColor)
                    : _TileCheckbox(
                        completed: _isCompleted,
                        size: 16 * density,
                      ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                onLongPress: onLongPress,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 2 * density),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5 * density.clamp(0.85, 1.0),
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      decoration: _isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppSemanticColors.textFaint(context),
                    ),
                  ),
                ),
              ),
            ),
            if (urgency != null) ...[
              SizedBox(width: 6 * density),
              _UrgencyBadge(label: urgency),
            ],
          ],
        ),
      ),
    );
  }
}

class _TileCheckbox extends StatelessWidget {
  const _TileCheckbox({required this.completed, required this.size});

  final bool completed;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppSemanticColors.successGreen,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.check, size: size * 0.68, color: Colors.white),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppSemanticColors.subtleBorder(context),
          width: 1.8,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Urgency badge
// ---------------------------------------------------------------------------

enum _UrgencyTier { overdue, today, soon, later, done }

class _UrgencyLabel {
  const _UrgencyLabel({required this.text, required this.tier});

  final String text;
  final _UrgencyTier tier;

  static _UrgencyLabel forTask(
    Task t,
    DateTime today, {
    required bool isCompleted,
    required int soonThresholdDays,
  }) {
    if (isCompleted) {
      return const _UrgencyLabel(text: 'DONE', tier: _UrgencyTier.done);
    }

    final score = matrixUrgencyScore(t, today);

    if (score < 0) {
      final days = -score;
      return _UrgencyLabel(
        text: days == 1 ? 'OVERDUE 1d' : 'OVERDUE ${days}d',
        tier: _UrgencyTier.overdue,
      );
    }
    if (score == 0) {
      return const _UrgencyLabel(text: 'Today', tier: _UrgencyTier.today);
    }
    if (score <= soonThresholdDays) {
      return _UrgencyLabel(
        text: score == 1 ? 'Tomorrow' : '${score}d',
        tier: _UrgencyTier.soon,
      );
    }
    return _UrgencyLabel(
      text: _shortDateForScore(today, score),
      tier: _UrgencyTier.later,
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDateForScore(DateTime today, int score) {
    final target = today.add(Duration(days: score));
    return '${_months[target.month - 1]} ${target.day}';
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.label});

  final _UrgencyLabel label;

  Color _bg(BuildContext context) {
    switch (label.tier) {
      case _UrgencyTier.overdue:
        return AppSemanticColors.dangerRed;
      case _UrgencyTier.today:
        return AppSemanticColors.warningOrange.withValues(alpha: 0.18);
      case _UrgencyTier.soon:
        return AppSemanticColors.warningOrange.withValues(alpha: 0.12);
      case _UrgencyTier.later:
        return AppSemanticColors.subtleBorder(context).withValues(alpha: 0.4);
      case _UrgencyTier.done:
        return AppSemanticColors.successGreen.withValues(alpha: 0.18);
    }
  }

  Color _fg(BuildContext context) {
    switch (label.tier) {
      case _UrgencyTier.overdue:
        return Colors.white;
      case _UrgencyTier.today:
        return AppSemanticColors.warningOrange;
      case _UrgencyTier.soon:
        return AppSemanticColors.warningOrange;
      case _UrgencyTier.later:
        return AppSemanticColors.textMuted(context);
      case _UrgencyTier.done:
        return AppSemanticColors.successGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bg(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: _fg(context),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
