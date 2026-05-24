import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/add_item_sheet.dart';
import '../../models/sub_task.dart';
import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_format.dart';
import '../../theme/app_theme.dart';
import 'task_snackbars.dart';
import 'task_streak_badge.dart';

/// Shows a compact, read-mostly view of a task as a bottom sheet. Surfaces
/// the title, quadrant, dates, notes, and an interactive subtask checklist.
/// Edit and delete actions live in the sheet.
///
/// Pair with list-row gestures: **tap** to complete (or expand subtasks on
/// Home), **long-press** to open this overview sheet.
Future<void> showTaskDetailSheet(
  BuildContext context, {
  required String taskId,
  DateTime? referenceDay,
  required Future<void> Function() onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskDetailSheet(
      taskId: taskId,
      referenceDay: referenceDay,
      onDelete: onDelete,
    ),
  );
}

class _TaskDetailSheet extends ConsumerWidget {
  const _TaskDetailSheet({
    required this.taskId,
    this.referenceDay,
    required this.onDelete,
  });

  final String taskId;
  final DateTime? referenceDay;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksListProvider);
    Task? task;
    for (final t in tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) {
      // Task vanished underneath us — dismiss silently.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    final activeTask = task;

    final settings = ref.watch(resolvedSettingsProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);
    final accent = quadrantColors[activeTask.quadrant] ?? activeTask.color;
    final theme = Theme.of(context);
    final now = referenceDay ?? DateTime.now();
    final referenceDate = DateTime(now.year, now.month, now.day);
    final done = activeTask.isCompletedOn(referenceDate);

    final streak = activeTask.isRecurring
        ? ref.watch(taskStreakProvider(activeTask.id))
        : null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppSemanticColors.tileBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppSemanticColors.subtleBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Header(
                task: activeTask,
                accent: accent,
                completed: done,
                showCompleteToggle: !activeTask.isEvent,
                streak: streak,
                onToggleComplete: () async {
                  // Completing the parent from the sheet implies "I'm done
                  // with the whole thing" — cascade into any unfinished
                  // subtasks instead of blocking on them.
                  if (!done &&
                      activeTask.hasSubtasks &&
                      !activeTask.allSubtasksComplete) {
                    await ref
                        .read(tasksProvider.notifier)
                        .toggleAllSubtasks(activeTask.id,
                            actionDay: referenceDate);
                    if (!context.mounted) return;
                    showTaskCompletedSnackBar(
                      context,
                      task: activeTask,
                      day: referenceDate,
                      recurring: activeTask.isRecurring,
                    );
                    return;
                  }
                  final result = await ref
                      .read(tasksProvider.notifier)
                      .toggleForDay(activeTask.id, referenceDate);
                  if (!context.mounted) return;
                  switch (result) {
                    case TaskToggleResult.completed:
                      showTaskCompletedSnackBar(
                        context,
                        task: activeTask,
                        day: referenceDate,
                        recurring: activeTask.isRecurring,
                      );
                    case TaskToggleResult.blockedSubtasks:
                      showSubtaskBlockedSnackBar(context);
                    case TaskToggleResult.uncompleted:
                    case TaskToggleResult.unchanged:
                      break;
                  }
                },
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 8),
              _MetaRow(
                task: activeTask,
                dateFormat: settings.dateFormat,
                accent: accent,
              ),
              if (activeTask.notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                _NotesBlock(notes: activeTask.notes),
              ],
              if (streak != null) ...[
                const SizedBox(height: 14),
                _StreakBlock(streak: streak, accent: accent),
              ],
              const SizedBox(height: 14),
              if (activeTask.subtasks.isNotEmpty) ...[
                _SubtaskList(
                  task: activeTask,
                  onToggle: (s) async {
                    final result =
                        await ref.read(tasksProvider.notifier).toggleSubtask(
                              activeTask.id,
                              s.id,
                              actionDay: referenceDate,
                            );
                    if (!context.mounted) return;
                    if (result.parentAutoCompleted) {
                      showSubtaskAutoCompletedSnackBar(
                        context,
                        task: activeTask,
                        subtaskId: s.id,
                        actionDay: referenceDate,
                        recurring: activeTask.isRecurring,
                      );
                    }
                  },
                ),
                const SizedBox(height: 14),
              ],
              if (activeTask.tags.isNotEmpty) ...[
                _TagsBlock(tags: activeTask.tags),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await onDelete();
                      },
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: theme.colorScheme.error.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        showAddItemSheet(context, taskToEdit: activeTask);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _Header extends StatelessWidget {
  const _Header({
    required this.task,
    required this.accent,
    required this.completed,
    required this.showCompleteToggle,
    required this.streak,
    required this.onToggleComplete,
    required this.onClose,
  });

  final Task task;
  final Color accent;
  final bool completed;
  final bool showCompleteToggle;
  final TaskStreak? streak;
  final VoidCallback onToggleComplete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCompleteToggle) ...[
          GestureDetector(
            onTap: onToggleComplete,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: completed
                      ? AppSemanticColors.successGreen
                      : AppSemanticColors.subtleBorder(context),
                  width: 2,
                ),
                color: completed
                    ? AppSemanticColors.successGreen
                    : Colors.transparent,
              ),
              child: completed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: completed
                      ? AppSemanticColors.textFaint(context)
                      : AppSemanticColors.textStrong(context),
                  decoration: completed
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${task.quadrant.label}  ·  ${task.kind == TaskKind.event ? 'Event' : (task.isRecurring ? 'Recurring task' : 'Task')}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppSemanticColors.textMuted(context),
                ),
              ),
            ],
          ),
        ),
        if (streak != null) ...[
          const SizedBox(width: 6),
          TaskStreakBadge(taskId: task.id, color: accent, size: 24),
        ],
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          tooltip: 'Close',
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.task,
    required this.dateFormat,
    required this.accent,
  });

  final Task task;
  final dynamic dateFormat;
  final Color accent;

  static const _weekdayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  String _dateLabel() {
    if (task.isMultiDay) {
      return formatDateRange(task.startDate, task.endDate!, dateFormat);
    }
    if (task.isRecurring) {
      final days = (task.recurrence!.weekdays.toList()..sort())
          .map((w) => _weekdayShort[w - 1])
          .join(' ');
      final until = task.recurrence!.until;
      return until == null
          ? 'Repeats $days  ·  Forever'
          : 'Repeats $days  ·  until ${formatDate(until, dateFormat)}';
    }
    return formatDateLong(task.startDate, dateFormat);
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = _timeLabel();
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _Chip(
          icon: Icons.calendar_today_outlined,
          label: _dateLabel(),
          accent: accent,
        ),
        if (timeLabel != null)
          _Chip(
            icon: Icons.schedule_outlined,
            label: timeLabel,
            accent: accent,
          ),
        if (!task.isEvent)
          _Chip(
            icon: _priorityIcon(),
            label: 'Priority: ${task.priority.name}',
            accent: _priorityColor(),
          ),
      ],
    );
  }

  IconData _priorityIcon() {
    switch (task.priority) {
      case TaskPriority.high:
        return Icons.flag;
      case TaskPriority.medium:
        return Icons.outlined_flag;
      case TaskPriority.low:
        return Icons.flag_outlined;
    }
  }

  Color _priorityColor() {
    switch (task.priority) {
      case TaskPriority.high:
        return const Color(0xFFEF5350);
      case TaskPriority.medium:
        return const Color(0xFFFF9800);
      case TaskPriority.low:
        return const Color(0xFF66BB6A);
    }
  }

  String? _timeLabel() {
    final s = task.startTime;
    final e = task.endTime;
    if (s == null && e == null) return null;
    if (s != null && e != null) {
      return '${s.formatTwelveHour()} – ${e.formatTwelveHour()}';
    }
    return (s ?? e)!.formatTwelveHour();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.accent});
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesBlock extends StatelessWidget {
  const _NotesBlock({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppSemanticColors.subtleSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppSemanticColors.textFaint(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppSemanticColors.textBody(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBlock extends StatelessWidget {
  const _StreakBlock({required this.streak, required this.accent});
  final TaskStreak streak;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final current = streak.current;
    final best = streak.best;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department_rounded, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current == 0
                      ? 'No active streak'
                      : '$current day${current == 1 ? '' : 's'} streak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppSemanticColors.textStrong(context),
                  ),
                ),
                Text(
                  'Best: $best day${best == 1 ? '' : 's'}',
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

class _SubtaskList extends StatelessWidget {
  const _SubtaskList({required this.task, required this.onToggle});
  final Task task;
  final ValueChanged<SubTask> onToggle;

  @override
  Widget build(BuildContext context) {
    final done = task.completedSubtaskCount;
    final total = task.subtasks.length;
    return Container(
      decoration: BoxDecoration(
        color: AppSemanticColors.subtleSurface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'SUBTASKS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppSemanticColors.textFaint(context),
                ),
              ),
              const Spacer(),
              Text(
                '$done / $total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppSemanticColors.textMuted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in task.subtasks)
            _SubtaskTile(subtask: s, onToggle: () => onToggle(s)),
        ],
      ),
    );
  }
}

class _SubtaskTile extends StatelessWidget {
  const _SubtaskTile({required this.subtask, required this.onToggle});
  final SubTask subtask;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final done = subtask.completed;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: done
                      ? AppSemanticColors.successGreen
                      : AppSemanticColors.subtleBorder(context),
                  width: 2,
                ),
                color:
                    done ? AppSemanticColors.successGreen : Colors.transparent,
              ),
              child: done
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 14,
                  color: done
                      ? AppSemanticColors.textFaint(context)
                      : AppSemanticColors.textStrong(context),
                  decoration:
                      done ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagsBlock extends StatelessWidget {
  const _TagsBlock({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppSemanticColors.subtleSurface(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#$t',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppSemanticColors.textMuted(context),
              ),
            ),
          ),
      ],
    );
  }
}
