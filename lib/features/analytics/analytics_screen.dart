import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/task.dart';
import '../../providers/clock_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_utils.dart';
import '../../theme/app_theme.dart';

/// How many days of history to render in every chart on this screen.
const int _windowDays = 21;

/// State of a single day for a single task.
enum _DayState { notApplicable, missed, done }

/// One day in the per-task chart.
class _TaskDayPoint {
  const _TaskDayPoint({required this.date, required this.state});
  final DateTime date;
  final _DayState state;
}

/// One day in the overall chart. `pct` is null when no recurring task
/// was scheduled that day (rendered as a faint placeholder).
class _OverallDayPoint {
  const _OverallDayPoint({required this.date, required this.pct});
  final DateTime date;
  final double? pct;
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String? _selectedTaskId;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksListProvider);
    final today = ref.watch(todayProvider);
    final recurring = tasks.where((t) => t.isRecurring).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: recurring.isEmpty
          ? const _EmptyState()
          : _Body(
              recurring: recurring,
              today: today,
              selectedTaskId: _selectedTaskId,
              onSelect: (id) => setState(() => _selectedTaskId = id),
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
    required this.today,
    required this.selectedTaskId,
    required this.onSelect,
  });

  final List<Task> recurring;
  final DateTime today;
  final String? selectedTaskId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quadrantColors = ref.watch(quadrantColorsProvider);
    final overallSeries = _overallSeries(recurring, today);

    // Default selection so the per-task block is meaningful on first open.
    final activeId = selectedTaskId ?? recurring.first.id;
    final selected = recurring.firstWhere(
      (t) => t.id == activeId,
      orElse: () => recurring.first,
    );
    final taskSeries = _taskSeries(selected, today);
    final streak = ref.watch(taskStreakProvider(selected.id));
    final accent = quadrantColors[selected.quadrant] ?? selected.color;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _Hero(),
        const SizedBox(height: 16),
        _OverallCard(series: overallSeries),
        const SizedBox(height: 18),
        _TaskPicker(
          tasks: recurring,
          value: selected.id,
          onChanged: onSelect,
        ),
        const SizedBox(height: 12),
        _TaskCard(
          task: selected,
          accent: accent,
          series: taskSeries,
          streak: streak,
        ),
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
          SvgPicture.asset(
            'assets/svg/analytics_hero.svg',
            width: 44,
            height: 44,
            colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
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
                  'Daily completion across $_windowDays days, with per-task '
                  'streaks below.',
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
    return _AnimatedBars(
      itemCount: series.length,
      // Bars sweep in only once when the screen mounts. Daily change won't
      // re-trigger because the length stays at _windowDays.
      signature: series.length,
      builder: (context, i, progress) {
        return _Bar(
          fillFraction: series[i].pct,
          progress: progress,
          fillColor: color,
          emptyColor: empty,
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fillFraction,
    required this.fillColor,
    required this.emptyColor,
    this.progress = 1.0,
  });

  /// `null` → render as a faint placeholder (day didn't apply).
  final double? fillFraction;
  final Color fillColor;
  final Color emptyColor;

  /// Animation fraction (0..1) used to scale the bar's grow-in height.
  final double progress;

  @override
  Widget build(BuildContext context) {
    if (fillFraction == null) {
      return LayoutBuilder(
        builder: (_, c) => Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 4,
            width: c.maxWidth,
            decoration: BoxDecoration(
              color: emptyColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    final raw = fillFraction!.clamp(0.0, 1.0);
    // Always show at least a sliver at rest so a tiny non-zero pct is visible.
    final shown = raw == 0 ? 0.0 : (raw < 0.04 ? 0.04 : raw);
    final animated = shown * progress;
    return LayoutBuilder(
      builder: (_, c) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: fillColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: c.maxHeight * animated,
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
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
// Task picker (dropdown)
// ---------------------------------------------------------------------------

class _TaskPicker extends StatelessWidget {
  const _TaskPicker({
    required this.tasks,
    required this.value,
    required this.onChanged,
  });

  final List<Task> tasks;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.tileBorder(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.expand_more_rounded,
            color: AppSemanticColors.textMuted(context),
          ),
          items: [
            for (final t in tasks)
              DropdownMenuItem(
                value: t.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: t.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppSemanticColors.textStrong(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-task card
// ---------------------------------------------------------------------------

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.accent,
    required this.series,
    required this.streak,
  });

  final Task task;
  final Color accent;
  final List<_TaskDayPoint> series;
  final TaskStreak streak;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeatDays = (task.recurrence!.weekdays.toList()..sort())
        .map((w) => _weekdayShort[w - 1])
        .join(' ');
    final applicable = series.where((p) => p.state != _DayState.notApplicable);
    final doneCount = applicable.where((p) => p.state == _DayState.done).length;
    final expectedCount = applicable.length;
    final rate = expectedCount == 0 ? 0.0 : doneCount / expectedCount;

    return _Card(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppSemanticColors.textStrong(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Repeats $repeatDays',
            style: TextStyle(
              fontSize: 12,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  label: 'Current',
                  value: '${streak.current}',
                  suffix: streak.current == 1 ? 'day' : 'days',
                  color: accent,
                  icon: Icons.local_fire_department_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBlock(
                  label: 'Best',
                  value: '${streak.best}',
                  suffix: streak.best == 1 ? 'day' : 'days',
                  color: theme.colorScheme.primary,
                  icon: Icons.emoji_events_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBlock(
                  label: 'Rate',
                  value: '${(rate * 100).round()}%',
                  suffix: '$doneCount/$expectedCount',
                  color: AppSemanticColors.successGreen,
                  icon: Icons.percent_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'LAST $_windowDays DAYS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppSemanticColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: _TaskBars(
              series: series,
              accent: accent,
              animationKey: task.id,
            ),
          ),
          const SizedBox(height: 8),
          _TaskLegend(accent: accent),
        ],
      ),
    );
  }
}

class _TaskBars extends StatelessWidget {
  const _TaskBars({
    required this.series,
    required this.accent,
    required this.animationKey,
  });

  final List<_TaskDayPoint> series;
  final Color accent;
  final Object animationKey;

  @override
  Widget build(BuildContext context) {
    final missed = AppSemanticColors.dangerRed.withValues(alpha: 0.55);
    final faint = AppSemanticColors.subtleBorder(context).withValues(alpha: 0.6);
    return _AnimatedBars(
      itemCount: series.length,
      // Changing the picked task replays the animation, so a dropdown swap
      // feels like a fresh chart sliding in instead of a static swap.
      signature: animationKey,
      builder: (context, i, progress) {
        return _TaskBar(
          state: series[i].state,
          accent: accent,
          missed: missed,
          faint: faint,
          progress: progress,
        );
      },
    );
  }
}

class _TaskBar extends StatelessWidget {
  const _TaskBar({
    required this.state,
    required this.accent,
    required this.missed,
    required this.faint,
    this.progress = 1.0,
  });

  final _DayState state;
  final Color accent;
  final Color missed;
  final Color faint;
  final double progress;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DayState.notApplicable:
        return LayoutBuilder(
          builder: (_, c) => Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 4,
              width: c.maxWidth,
              decoration: BoxDecoration(
                color: faint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      case _DayState.missed:
        return LayoutBuilder(
          builder: (_, c) => Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: c.maxHeight * 0.18 * progress,
              width: c.maxWidth,
              decoration: BoxDecoration(
                color: missed,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      case _DayState.done:
        return LayoutBuilder(
          builder: (_, c) => Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: c.maxHeight * progress,
              width: c.maxWidth,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
    }
  }
}

class _TaskLegend extends StatelessWidget {
  const _TaskLegend({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Swatch(color: accent, label: 'Done'),
        const SizedBox(width: 12),
        _Swatch(
          color: AppSemanticColors.dangerRed.withValues(alpha: 0.55),
          label: 'Missed',
        ),
        const SizedBox(width: 12),
        _Swatch(
          color: AppSemanticColors.subtleBorder(context),
          label: 'Not scheduled',
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppSemanticColors.textFaint(context),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat block
// ---------------------------------------------------------------------------

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String suffix;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppSemanticColors.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            suffix,
            style: TextStyle(
              fontSize: 10,
              color: AppSemanticColors.textMuted(context),
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
  const _Card({required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppSemanticColors.tileBackground(context),
        borderRadius: BorderRadius.circular(14),
        border: accent == null
            ? Border.all(color: AppSemanticColors.tileBorder(context))
            : Border(left: BorderSide(color: accent!, width: 4)),
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
            SvgPicture.asset(
              'assets/svg/analytics_empty.svg',
              width: 200,
              height: 150,
              colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
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
// Staggered bar animator — sweeps bars in from the baseline left-to-right.
// ---------------------------------------------------------------------------

class _AnimatedBars extends StatefulWidget {
  const _AnimatedBars({
    required this.itemCount,
    required this.builder,
    required this.signature,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index, double progress)
      builder;

  /// When this value changes, the animation resets and replays. Use a stable
  /// value (e.g. list length) to animate once, or a changing value (e.g. a
  /// selected id) to re-animate on each switch.
  final Object signature;

  @override
  State<_AnimatedBars> createState() => _AnimatedBarsState();
}

class _AnimatedBarsState extends State<_AnimatedBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Each individual bar's grow-in occupies this fraction of total animation
  /// time. The remainder is the stagger window across bars.
  static const double _barSlice = 0.45;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signature != oldWidget.signature) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: widget.builder(
                    context,
                    i,
                    _easedProgressFor(i),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  double _easedProgressFor(int index) {
    if (widget.itemCount <= 1) {
      return Curves.easeOutCubic.transform(_controller.value);
    }
    final start =
        (index / (widget.itemCount - 1)) * (1 - _barSlice);
    final local =
        ((_controller.value - start) / _barSlice).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(local);
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
    int applicable = 0;
    int done = 0;
    for (final t in recurring) {
      if (d.isBefore(dateOnly(t.startDate))) continue;
      if (!t.recurrence!.appliesOn(d)) continue;
      applicable++;
      if (t.completedDates.any((c) => sameDay(c, d))) done++;
    }
    out.add(_OverallDayPoint(
      date: d,
      pct: applicable == 0 ? null : done / applicable,
    ));
  }
  return out;
}

List<_TaskDayPoint> _taskSeries(Task task, DateTime today) {
  final todayD = dateOnly(today);
  final start = dateOnly(task.startDate);
  final out = <_TaskDayPoint>[];
  for (var i = _windowDays - 1; i >= 0; i--) {
    final d = todayD.subtract(Duration(days: i));
    if (d.isBefore(start) || !task.recurrence!.appliesOn(d)) {
      out.add(_TaskDayPoint(date: d, state: _DayState.notApplicable));
      continue;
    }
    final done = task.completedDates.any((c) => sameDay(c, d));
    out.add(_TaskDayPoint(
      date: d,
      state: done ? _DayState.done : _DayState.missed,
    ));
  }
  return out;
}
