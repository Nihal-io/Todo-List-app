import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../providers/matrix_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_theme.dart';

class MatrixScreen extends ConsumerWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(matrixItemsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(title: const Text('Matrix')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        child: Column(
          children: [
            const _TopAxisLabels(),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SideAxisLabels(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _QuadrantSection(
                                  quadrant: MatrixQuadrant.schedule,
                                  tasks: items[MatrixQuadrant.schedule] ?? const [],
                                  today: today,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuadrantSection(
                                  quadrant: MatrixQuadrant.doFirst,
                                  tasks: items[MatrixQuadrant.doFirst] ?? const [],
                                  today: today,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: _QuadrantSection(
                                  quadrant: MatrixQuadrant.eliminate,
                                  tasks: items[MatrixQuadrant.eliminate] ?? const [],
                                  today: today,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _QuadrantSection(
                                  quadrant: MatrixQuadrant.delegate,
                                  tasks: items[MatrixQuadrant.delegate] ?? const [],
                                  today: today,
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
          ],
        ),
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

class _QuadrantSection extends ConsumerWidget {
  const _QuadrantSection({
    required this.quadrant,
    required this.tasks,
    required this.today,
  });

  final MatrixQuadrant quadrant;
  final List<Task> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = quadrant.color;
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
          _QuadrantHeader(quadrant: quadrant, count: tasks.length),
          Expanded(
            child: tasks.isEmpty
                ? _EmptyQuadrant(quadrant: quadrant)
                : _QuadrantList(
                    tasks: tasks,
                    today: today,
                    onToggle: (t) =>
                        ref.read(tasksProvider.notifier).toggleForDay(t.id, today),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuadrantHeader extends StatelessWidget {
  const _QuadrantHeader({required this.quadrant, required this.count});

  final MatrixQuadrant quadrant;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = quadrant.color;
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

class _QuadrantList extends StatelessWidget {
  const _QuadrantList({
    required this.tasks,
    required this.today,
    required this.onToggle,
  });

  final List<Task> tasks;
  final DateTime today;
  final ValueChanged<Task> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final task = tasks[i];
        return _MatrixTaskTile(
          task: task,
          today: today,
          onToggle: () => onToggle(task),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyQuadrant extends StatelessWidget {
  const _EmptyQuadrant({required this.quadrant});

  final MatrixQuadrant quadrant;

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
    final color = quadrant.color;
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

class _MatrixTaskTile extends StatelessWidget {
  const _MatrixTaskTile({
    required this.task,
    required this.today,
    required this.onToggle,
  });

  final Task task;
  final DateTime today;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final urgency = _UrgencyLabel.forTask(task, today, context);
    final tileColor = AppSemanticColors.subtleSurface(context);

    return Container(
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: task.color, width: 3)),
      ),
      child: InkWell(
        onTap: task.isEvent ? null : onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (task.isEvent)
                Icon(Icons.event, size: 16, color: task.color)
              else
                _TileCheckbox(color: task.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _UrgencyBadge(label: urgency),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileCheckbox extends StatelessWidget {
  const _TileCheckbox({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
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

enum _UrgencyTier { overdue, today, soon, later }

class _UrgencyLabel {
  const _UrgencyLabel({required this.text, required this.tier});

  final String text;
  final _UrgencyTier tier;

  /// Computes the badge label and tier from the task's urgency score.
  /// Recurring tasks active today show as "Today"; otherwise the
  /// next-occurrence delta is used.
  static _UrgencyLabel forTask(Task t, DateTime today, BuildContext context) {
    final score = matrixUrgencyScore(t, today);

    if (score < 0) {
      final days = -score;
      return _UrgencyLabel(
        text: days == 1 ? '1d late' : '${days}d late',
        tier: _UrgencyTier.overdue,
      );
    }
    if (score == 0) {
      return const _UrgencyLabel(text: 'Today', tier: _UrgencyTier.today);
    }
    if (score <= 3) {
      return _UrgencyLabel(
        text: score == 1 ? 'Tomorrow' : '${score}d',
        tier: _UrgencyTier.soon,
      );
    }
    return _UrgencyLabel(
      text: _shortDateForScore(t, today, score),
      tier: _UrgencyTier.later,
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _shortDateForScore(Task t, DateTime today, int score) {
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
        return AppSemanticColors.dangerRed.withValues(alpha: 0.14);
      case _UrgencyTier.today:
        return AppSemanticColors.warningOrange.withValues(alpha: 0.18);
      case _UrgencyTier.soon:
        return AppSemanticColors.warningOrange.withValues(alpha: 0.12);
      case _UrgencyTier.later:
        return AppSemanticColors.subtleBorder(context).withValues(alpha: 0.4);
    }
  }

  Color _fg(BuildContext context) {
    switch (label.tier) {
      case _UrgencyTier.overdue:
        return AppSemanticColors.dangerRed;
      case _UrgencyTier.today:
        return AppSemanticColors.warningOrange;
      case _UrgencyTier.soon:
        return AppSemanticColors.warningOrange;
      case _UrgencyTier.later:
        return AppSemanticColors.textMuted(context);
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
