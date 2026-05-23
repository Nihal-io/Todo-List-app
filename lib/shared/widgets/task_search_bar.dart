import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/search_filter_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

/// Compact search input + filter row used at the top of Home / Grid screens.
/// Reads/writes [taskFilterProvider] and [searchBarOpenProvider] directly so
/// callers just drop this widget into their layout.
class TaskSearchBar extends ConsumerStatefulWidget {
  const TaskSearchBar({super.key});

  @override
  ConsumerState<TaskSearchBar> createState() => _TaskSearchBarState();
}

class _TaskSearchBarState extends ConsumerState<TaskSearchBar> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(taskFilterProvider).query);
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppSemanticColors.subtleSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.search,
                  size: 18, color: AppSemanticColors.textFaint(context)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onChanged: (v) => ref
                      .read(taskFilterProvider.notifier)
                      .update((f) => f.copyWith(query: v)),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: 'Search title, notes, or subtasks',
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              if (filter.query.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: AppSemanticColors.textFaint(context)),
                  onPressed: () {
                    _controller.clear();
                    ref
                        .read(taskFilterProvider.notifier)
                        .update((f) => f.copyWith(query: ''));
                  },
                  tooltip: 'Clear search',
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: AppSemanticColors.textMuted(context)),
                tooltip: 'Close',
                onPressed: () {
                  ref.read(searchBarOpenProvider.notifier).state = false;
                  ref.read(taskFilterProvider.notifier).state =
                      const TaskFilter();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                _StatusChip(filter: filter),
                const SizedBox(width: 6),
                _KindChip(filter: filter),
                const SizedBox(width: 6),
                for (final q in MatrixQuadrant.values) ...[
                  _QuadrantFilterChip(
                    quadrant: q,
                    color: quadrantColors[q] ?? q.color,
                    filter: filter,
                  ),
                  const SizedBox(width: 6),
                ],
                for (final p in TaskPriority.values) ...[
                  _PriorityFilterChip(
                    priority: p,
                    filter: filter,
                  ),
                  const SizedBox(width: 6),
                ],
                if (filter.isActive)
                  TextButton.icon(
                    onPressed: () => ref
                        .read(taskFilterProvider.notifier)
                        .state = const TaskFilter(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

class _StatusChip extends ConsumerWidget {
  const _StatusChip({required this.filter});
  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<TaskStatusFilter>(
      itemBuilder: (_) => const [
        PopupMenuItem(value: TaskStatusFilter.any, child: Text('Any status')),
        PopupMenuItem(value: TaskStatusFilter.open, child: Text('Open')),
        PopupMenuItem(value: TaskStatusFilter.done, child: Text('Done')),
      ],
      onSelected: (v) => ref
          .read(taskFilterProvider.notifier)
          .update((f) => f.copyWith(status: v)),
      child: _FilterChipShell(
        selected: filter.status != TaskStatusFilter.any,
        label: switch (filter.status) {
          TaskStatusFilter.any => 'Status',
          TaskStatusFilter.open => 'Open',
          TaskStatusFilter.done => 'Done',
        },
        icon: Icons.check_circle_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _KindChip extends ConsumerWidget {
  const _KindChip({required this.filter});
  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<TaskKindFilter>(
      itemBuilder: (_) => const [
        PopupMenuItem(value: TaskKindFilter.any, child: Text('Any kind')),
        PopupMenuItem(value: TaskKindFilter.task, child: Text('Tasks only')),
        PopupMenuItem(value: TaskKindFilter.event, child: Text('Events only')),
        PopupMenuItem(
            value: TaskKindFilter.recurring, child: Text('Recurring only')),
      ],
      onSelected: (v) => ref
          .read(taskFilterProvider.notifier)
          .update((f) => f.copyWith(kind: v)),
      child: _FilterChipShell(
        selected: filter.kind != TaskKindFilter.any,
        label: switch (filter.kind) {
          TaskKindFilter.any => 'Kind',
          TaskKindFilter.task => 'Tasks',
          TaskKindFilter.event => 'Events',
          TaskKindFilter.recurring => 'Recurring',
        },
        icon: Icons.style_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _QuadrantFilterChip extends ConsumerWidget {
  const _QuadrantFilterChip({
    required this.quadrant,
    required this.color,
    required this.filter,
  });

  final MatrixQuadrant quadrant;
  final Color color;
  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = filter.quadrants.contains(quadrant);
    return GestureDetector(
      onTap: () {
        final next = {...filter.quadrants};
        if (selected) {
          next.remove(quadrant);
        } else {
          next.add(quadrant);
        }
        ref
            .read(taskFilterProvider.notifier)
            .update((f) => f.copyWith(quadrants: next));
      },
      child: _FilterChipShell(
        selected: selected,
        label: quadrant.label,
        color: color,
      ),
    );
  }
}

class _PriorityFilterChip extends ConsumerWidget {
  const _PriorityFilterChip({required this.priority, required this.filter});

  final TaskPriority priority;
  final TaskFilter filter;

  static const _colors = {
    TaskPriority.low: Color(0xFF66BB6A),
    TaskPriority.medium: Color(0xFFFF9800),
    TaskPriority.high: Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colors[priority]!;
    final selected = filter.priorities.contains(priority);
    return GestureDetector(
      onTap: () {
        final next = {...filter.priorities};
        if (selected) {
          next.remove(priority);
        } else {
          next.add(priority);
        }
        ref
            .read(taskFilterProvider.notifier)
            .update((f) => f.copyWith(priorities: next));
      },
      child: _FilterChipShell(
        selected: selected,
        label: priority.name,
        color: color,
      ),
    );
  }
}

class _FilterChipShell extends StatelessWidget {
  const _FilterChipShell({
    required this.selected,
    required this.label,
    this.icon,
    this.color,
  });

  final bool selected;
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? tone : tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? tone : tone.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 14,
                color: selected ? Colors.white : tone),
            const SizedBox(width: 4),
          ],
          Text(
            label[0].toUpperCase() + label.substring(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : tone,
            ),
          ),
        ],
      ),
    );
  }
}
