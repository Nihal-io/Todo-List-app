import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/recurring_completion.dart';
import '../../models/task.dart';
import '../../providers/clock_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_utils.dart';
import '../../theme/app_theme.dart';

/// How many days of history to render in the overall chart.
const int _windowDays = kRecurringAnalyticsWindowDays;

/// One day in the overall chart. `pct` is null when no recurring task was
/// scheduled that day (rendered as a faint placeholder so the gap reads as
/// "nothing scheduled" rather than 0%).
class _OverallDayPoint {
  const _OverallDayPoint({required this.date, required this.pct});
  final DateTime date;
  final double? pct;
}

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksListProvider);
    final today = ref.watch(todayProvider);
    final recurring = tasks.where((t) => t.isRecurring).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: recurring.isEmpty
          ? const _EmptyState()
          : _Body(
              recurring: recurring,
              allTasks: tasks,
              today: today,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _Body extends ConsumerWidget {
  const _Body({
    required this.recurring,
    required this.allTasks,
    required this.today,
  });

  final List<Task> recurring;
  final List<Task> allTasks;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallSeries = _overallSeries(recurring, today);
    final totalRate = totalRecurringCompletionRate(recurring, today);
    final overdueRate = oneOffOverdueRate(allTasks, today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _Hero(),
        const SizedBox(height: 16),
        _OverallCard(series: overallSeries),
        const SizedBox(height: 12),
        _CompletionRateCard(
          totalRate: totalRate,
          overdueRate: overdueRate,
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            'STREAKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
        ),
        for (final task in recurring) ...[
          _StreakRow(task: task),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero — SVG header
// ---------------------------------------------------------------------------

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.10),
            primary.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.insights_rounded, size: 26, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recurring task analytics',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Daily completion across $_windowDays days. Subtasks count '
                  'as partial credit on today\'s bar.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppSemanticColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overall card
// ---------------------------------------------------------------------------

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.series});

  final List<_OverallDayPoint> series;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final scored = series.where((d) => d.pct != null).toList();
    final avg = scored.isEmpty
        ? null
        : scored.map((d) => d.pct!).reduce((a, b) => a + b) / scored.length;
    final todayPct = series.isNotEmpty ? series.last.pct : null;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OVERALL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                todayPct == null ? '—' : '${(todayPct * 100).round()}%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  todayPct == null
                      ? 'nothing scheduled today'
                      : 'today',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppSemanticColors.textMuted(context),
                  ),
                ),
              ),
              const Spacer(),
              if (avg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'avg ${(avg * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppSemanticColors.textMuted(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: _OverallBars(series: series, color: primary),
          ),
          const SizedBox(height: 8),
          _AxisLabels(series: series),
        ],
      ),
    );
  }
}

class _OverallBars extends StatelessWidget {
  const _OverallBars({required this.series, required this.color});

  final List<_OverallDayPoint> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final empty = AppSemanticColors.subtleBorder(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final pt in series)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: _Bar(
                fillFraction: pt.pct,
                fillColor: color,
                emptyColor: empty,
              ),
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fillFraction,
    required this.fillColor,
    required this.emptyColor,
  });

  /// `null` → render as a faint placeholder (day didn't apply).
  final double? fillFraction;
  final Color fillColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    if (fillFraction == null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          widthFactor: 1.0,
          heightFactor: 0.04,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: emptyColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    final raw = fillFraction!.clamp(0.0, 1.0);
    // Tiny non-zero values still render a 4% sliver so they're visible at all.
    final shown = raw == 0 ? 0.0 : (raw < 0.04 ? 0.04 : raw);
    return Stack(
      children: [
        // Faint full-height background so the bar slot has visible "track".
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fillColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        if (shown > 0)
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: shown,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.series});

  final List<_OverallDayPoint> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SizedBox.shrink();
    final first = series.first.date;
    final mid = series[series.length ~/ 2].date;
    final last = series.last.date;
    final style = TextStyle(
      fontSize: 10,
      color: AppSemanticColors.textFaint(context),
    );
    String fmt(DateTime d) => '${d.day}/${d.month}';
    return Row(
      children: [
        Text(fmt(first), style: style),
        const Spacer(),
        Text(fmt(mid), style: style),
        const Spacer(),
        Text(fmt(last), style: style),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Completion rate — aggregate + one-off overdue share
// ---------------------------------------------------------------------------

class _CompletionRateCard extends StatelessWidget {
  const _CompletionRateCard({
    required this.totalRate,
    required this.overdueRate,
  });

  final double? totalRate;
  final double? overdueRate;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final error = Theme.of(context).colorScheme.error;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLETION RATE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                totalRate == null ? '—' : '${(totalRate! * 100).round()}%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: primary,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  totalRate == null
                      ? 'no scheduled days in window'
                      : 'total · last $_windowDays days',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppSemanticColors.textMuted(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalRate == null
                ? 'Add recurring weekdays in this period to see your rate.'
                : 'Every scheduled occurrence counts. Missed days lower this '
                    'number; today can include partial credit from subtasks.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppSemanticColors.subtleBorder(context)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: overdueRate != null && overdueRate! > 0
                    ? error
                    : AppSemanticColors.textFaint(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tasks that went overdue',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppSemanticColors.textStrong(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      overdueRate == null
                          ? 'No one-off tasks have reached their deadline yet.'
                          : '${(overdueRate! * 100).round()}% of one-off tasks '
                              'past deadline are still incomplete. Recurring '
                              'tasks are excluded — they use missed days, not '
                              'overdue.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppSemanticColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (overdueRate != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${(overdueRate! * 100).round()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: overdueRate! > 0 ? error : primary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-task streak row (no graph — task completion is binary)
// ---------------------------------------------------------------------------

class _StreakRow extends ConsumerWidget {
  const _StreakRow({required this.task});

  final Task task;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quadrantColors = ref.watch(quadrantColorsProvider);
    final accent = quadrantColors[task.quadrant] ?? task.color;
    final streak = ref.watch(taskStreakProvider(task.id));
    final theme = Theme.of(context);

    final repeatDays = (task.recurrence!.weekdays.toList()..sort())
        .map((w) => _weekdayShort[w - 1])
        .join(' ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.softShadow(context),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Repeats $repeatDays',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppSemanticColors.textMuted(context),
                  ),
                ),
              ],
            ),
          ),
          _StreakChip(
            icon: Icons.local_fire_department_rounded,
            value: streak.current,
            label: 'now',
            color: accent,
          ),
          const SizedBox(width: 8),
          _StreakChip(
            icon: Icons.emoji_events_rounded,
            value: streak.best,
            label: 'best',
            color: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? color.withValues(alpha: 0.35)
              : AppSemanticColors.subtleBorder(context),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 12,
                  color: active
                      ? color
                      : AppSemanticColors.textFaint(context)),
              const SizedBox(width: 3),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? color
                      : AppSemanticColors.textMuted(context),
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppSemanticColors.textFaint(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable card shell
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppSemanticColors.tileBorder(context)),
        boxShadow: [
          BoxShadow(
            color: AppSemanticColors.softShadow(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: primary.withValues(alpha: 0.22)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.insights_outlined,
                size: 64,
                color: primary.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No recurring tasks yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppSemanticColors.textStrong(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add a recurring task (repeats on selected weekdays) and your '
              'completion graph and streaks will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppSemanticColors.textMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Series computation
// ---------------------------------------------------------------------------

List<_OverallDayPoint> _overallSeries(List<Task> recurring, DateTime today) {
  final todayD = dateOnly(today);
  final out = <_OverallDayPoint>[];
  for (var i = _windowDays - 1; i >= 0; i--) {
    final d = todayD.subtract(Duration(days: i));
    final contributions = <double>[];
    for (final t in recurring) {
      if (d.isBefore(dateOnly(t.startDate))) continue;
      if (!t.recurrence!.appliesOn(d)) continue;
      contributions.add(recurringDayCompletionCredit(t, d, todayD));
    }
    out.add(_OverallDayPoint(
      date: d,
      pct: contributions.isEmpty
          ? null
          : contributions.reduce((a, b) => a + b) / contributions.length,
    ));
  }
  return out;
}
