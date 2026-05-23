import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/sub_task.dart';
import '../../models/task.dart';
import '../../providers/selected_day_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../shared/date_format.dart';
import '../../theme/app_theme.dart';

const _uuid = Uuid();

void showAddItemSheet(
  BuildContext context, {
  DateTime? initialDate,
  Task? taskToEdit,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _AddItemSheet(initialDate: initialDate, taskToEdit: taskToEdit),
  );
}

const List<int> _weekdayOrder = [
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];
const List<String> _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet({this.initialDate, this.taskToEdit});

  final DateTime? initialDate;
  final Task? taskToEdit;

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _newSubtaskController = TextEditingController();
  final FocusNode _newSubtaskFocus = FocusNode();

  TaskKind _kind = TaskKind.task;
  late DateTime _startDate;
  DateTime? _endDate;
  MatrixQuadrant _quadrant = kDefaultQuadrant;
  TaskPriority _priority = TaskPriority.medium;

  final Set<int> _weekdays = <int>{};
  bool _repeatForever = true;
  DateTime? _repeatUntil;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<SubTask> _subtasks = <SubTask>[];

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;
    if (task != null) {
      _titleController.text = task.title;
      _notesController.text = task.notes;
      _kind = task.kind;
      _startDate = task.startDate;
      _endDate = task.endDate;
      _quadrant = task.quadrant;
      _priority = task.priority;
      _startTime = task.startTime?.toTimeOfDay();
      _endTime = task.endTime?.toTimeOfDay();
      _subtasks.addAll(task.subtasks);
      if (task.isRecurring) {
        _weekdays.addAll(task.recurrence!.weekdays);
        _repeatUntil = task.recurrence!.until;
        _repeatForever = task.recurrence!.until == null;
      }
    } else {
      _startDate =
          widget.initialDate ?? ref.read(selectedCalendarDayProvider);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _newSubtaskController.dispose();
    _newSubtaskFocus.dispose();
    super.dispose();
  }

  bool get _isRecurring => _kind == TaskKind.task && _weekdays.isNotEmpty;
  bool get _isEditing => widget.taskToEdit != null;

  bool get _canSubmit {
    if (_titleController.text.trim().isEmpty) return false;
    if (_kind == TaskKind.event && _endDate == null) return false;
    if (_isRecurring && !_repeatForever && _repeatUntil == null) return false;
    return true;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
        }
        if (_repeatUntil != null && _repeatUntil!.isBefore(_startDate)) {
          _repeatUntil = null;
          _repeatForever = true;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 1)),
      firstDate: _startDate,
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(DateTime.now().year + 10),
    );
    if (picked != null) {
      setState(() {
        _repeatUntil = picked;
        _repeatForever = false;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_endTime != null &&
            (_endTime!.hour < picked.hour ||
                (_endTime!.hour == picked.hour &&
                    _endTime!.minute <= picked.minute))) {
          _endTime = null;
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ??
          (_startTime == null
              ? const TimeOfDay(hour: 10, minute: 0)
              : TimeOfDay(
                  hour: (_startTime!.hour + 1) % 24,
                  minute: _startTime!.minute,
                )),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  void _clearEndDate() => setState(() => _endDate = null);

  void _toggleWeekday(int w) => setState(() {
        if (_weekdays.contains(w)) {
          _weekdays.remove(w);
        } else {
          _weekdays.add(w);
        }
      });

  void _addSubtask() {
    final t = _newSubtaskController.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _subtasks.add(SubTask(id: _uuid.v4(), title: t));
      _newSubtaskController.clear();
    });
    _newSubtaskFocus.requestFocus();
  }

  void _toggleSubtask(int index) {
    setState(() {
      final s = _subtasks[index];
      _subtasks[index] = s.copyWith(completed: !s.completed);
    });
  }

  void _removeSubtask(int index) =>
      setState(() => _subtasks.removeAt(index));

  void _editSubtaskTitle(int index, String value) {
    setState(() {
      _subtasks[index] = _subtasks[index].copyWith(title: value);
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    final id = widget.taskToEdit?.id ?? _uuid.v4();

    final startTaskTime =
        _startTime == null ? null : TaskTime.fromTimeOfDay(_startTime!);
    final endTaskTime =
        _endTime == null ? null : TaskTime.fromTimeOfDay(_endTime!);

    final cleanedSubtasks =
        _subtasks.where((s) => s.title.trim().isNotEmpty).toList();

    Task task;
    if (_kind == TaskKind.event) {
      task = Task(
        id: id,
        title: title,
        startDate: _startDate,
        endDate: _endDate,
        kind: TaskKind.event,
        quadrant: _quadrant,
        completed: widget.taskToEdit?.completed ?? false,
        notes: notes,
        subtasks: cleanedSubtasks,
        startTime: startTaskTime,
        endTime: endTaskTime,
        sortIndex: widget.taskToEdit?.sortIndex,
      );
    } else if (_isRecurring) {
      task = Task(
        id: id,
        title: title,
        startDate: _startDate,
        kind: TaskKind.task,
        recurrence: WeeklyRecurrence(
          weekdays: Set<int>.from(_weekdays),
          until: _repeatForever ? null : _repeatUntil,
        ),
        priority: _priority,
        quadrant: _quadrant,
        completedDates: widget.taskToEdit?.isRecurring == true
            ? widget.taskToEdit!.completedDates
            : null,
        notes: notes,
        subtasks: cleanedSubtasks,
        startTime: startTaskTime,
        sortIndex: widget.taskToEdit?.sortIndex,
      );
    } else {
      task = Task(
        id: id,
        title: title,
        startDate: _startDate,
        endDate: _endDate,
        kind: TaskKind.task,
        priority: _priority,
        quadrant: _quadrant,
        completed: widget.taskToEdit?.isRecurring != true
            ? (widget.taskToEdit?.completed ?? false)
            : false,
        notes: notes,
        subtasks: cleanedSubtasks,
        startTime: startTaskTime,
        sortIndex: widget.taskToEdit?.sortIndex,
      );
    }

    if (_isEditing) {
      ref.read(tasksProvider.notifier).updateTask(task);
    } else {
      ref.read(tasksProvider.notifier).add(task);
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
            'Remove "${widget.taskToEdit!.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(tasksProvider.notifier).remove(widget.taskToEdit!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final settings = ref.watch(resolvedSettingsProvider);
    final quadrantColors = ref.watch(quadrantColorsProvider);

    final startLabel = formatDateLong(_startDate, settings.dateFormat);
    final endLabel = _endDate == null
        ? (_kind == TaskKind.event
            ? 'Until… (required)'
            : 'Until… (single day)')
        : formatDateLong(_endDate!, settings.dateFormat);
    final untilLabel = _repeatUntil == null
        ? 'Pick a date'
        : formatDateLong(_repeatUntil!, settings.dateFormat);

    final isTask = _kind == TaskKind.task;
    final showSimpleUntil = !_isRecurring;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: AppSemanticColors.tileBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing
                          ? (_kind == TaskKind.event
                              ? 'Edit Event'
                              : 'Edit Task')
                          : (_kind == TaskKind.event
                              ? 'New Event'
                              : 'New Task'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_isEditing)
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      tooltip: 'Delete',
                      onPressed: _confirmDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<TaskKind>(
                segments: const [
                  ButtonSegment(
                    value: TaskKind.task,
                    label: Text('Task'),
                    icon: Icon(Icons.task_alt_outlined),
                  ),
                  ButtonSegment(
                    value: TaskKind.event,
                    label: Text('Event'),
                    icon: Icon(Icons.event_outlined),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (val) {
                  setState(() {
                    _kind = val.first;
                    if (_kind == TaskKind.event) {
                      _weekdays.clear();
                      _repeatForever = true;
                      _repeatUntil = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: isTask ? 'Task name' : 'Event name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Notes'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Add a description or context (optional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              const _SectionLabel('Quadrant'),
              const SizedBox(height: 8),
              _QuadrantPicker(
                quadrant: _quadrant,
                quadrantColors: quadrantColors,
                onChanged: (q) => setState(() => _quadrant = q),
              ),
              const SizedBox(height: 16),
              if (isTask) ...[
                const _SectionLabel('Priority'),
                const SizedBox(height: 8),
                _PriorityPicker(
                  priority: _priority,
                  onChanged: (p) => setState(() => _priority = p),
                ),
                const SizedBox(height: 16),
              ],
              const _SectionLabel('When'),
              const SizedBox(height: 8),
              _PickerRow(
                icon: Icons.calendar_today_outlined,
                label: startLabel,
                primary: primary,
                onTap: _pickStartDate,
              ),
              if (showSimpleUntil) ...[
                const SizedBox(height: 8),
                _PickerRow(
                  icon: Icons.date_range_outlined,
                  label: endLabel,
                  primary: primary,
                  onTap: _pickEndDate,
                  trailing: _endDate == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          color: AppSemanticColors.textFaint(context),
                          onPressed: _clearEndDate,
                          tooltip: 'Make single-day',
                        ),
                ),
              ],
              const SizedBox(height: 12),
              const _SectionLabel('Time of day (optional)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PickerRow(
                      icon: Icons.schedule_outlined,
                      label: _startTime == null
                          ? 'Start time'
                          : _startTime!.format(context),
                      primary: primary,
                      onTap: _pickStartTime,
                      trailing: _startTime == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              color: AppSemanticColors.textFaint(context),
                              onPressed: () =>
                                  setState(() => _startTime = null),
                              tooltip: 'Clear',
                            ),
                    ),
                  ),
                  if (_kind == TaskKind.event) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PickerRow(
                        icon: Icons.timer_off_outlined,
                        label: _endTime == null
                            ? 'End time'
                            : _endTime!.format(context),
                        primary: primary,
                        onTap: _pickEndTime,
                        trailing: _endTime == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                color: AppSemanticColors.textFaint(context),
                                onPressed: () =>
                                    setState(() => _endTime = null),
                                tooltip: 'Clear',
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              if (isTask) ...[
                const SizedBox(height: 16),
                const _SectionLabel('Repeat'),
                const SizedBox(height: 8),
                _WeekdayPicker(
                  selected: _weekdays,
                  onToggle: _toggleWeekday,
                  color: primary,
                ),
                if (_isRecurring) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel('Repeats until'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ChoiceChip(
                        label: 'Forever',
                        selected: _repeatForever,
                        color: primary,
                        onTap: () => setState(() {
                          _repeatForever = true;
                          _repeatUntil = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _ChoiceChip(
                        label: untilLabel,
                        selected: !_repeatForever,
                        color: primary,
                        onTap: _pickRepeatUntil,
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 16),
              const _SectionLabel('Subtasks'),
              const SizedBox(height: 8),
              _SubtaskEditor(
                subtasks: _subtasks,
                onToggle: _toggleSubtask,
                onRemove: _removeSubtask,
                onEdit: _editSubtaskTitle,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newSubtaskController,
                      focusNode: _newSubtaskFocus,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addSubtask(),
                      decoration: InputDecoration(
                        hintText: 'Add a subtask',
                        prefixIcon: Icon(
                          Icons.add_task,
                          size: 18,
                          color: AppSemanticColors.textFaint(context),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _addSubtask,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add subtask',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppSemanticColors.subtleBorder(context),
                  disabledForegroundColor:
                      AppSemanticColors.textFaint(context),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _isEditing ? 'Save' : 'Add',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppSemanticColors.textFaint(context),
        letterSpacing: 0.8,
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color primary;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppSemanticColors.subtleBorder(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppSemanticColors.textStrong(context),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _QuadrantPicker extends StatelessWidget {
  const _QuadrantPicker({
    required this.quadrant,
    required this.quadrantColors,
    required this.onChanged,
  });

  final MatrixQuadrant quadrant;
  final Map<MatrixQuadrant, Color> quadrantColors;
  final ValueChanged<MatrixQuadrant> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: MatrixQuadrant.values.map((q) {
        final selected = q == quadrant;
        final color = quadrantColors[q] ?? q.color;
        return GestureDetector(
          onTap: () => onChanged(q),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    q.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : AppSemanticColors.textStrong(context),
                    ),
                  ),
                ),
                Text(
                  q.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppSemanticColors.textFaint(context),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.priority, required this.onChanged});

  final TaskPriority priority;
  final ValueChanged<TaskPriority> onChanged;

  static const _colors = {
    TaskPriority.low: Color(0xFF66BB6A),
    TaskPriority.medium: Color(0xFFFF9800),
    TaskPriority.high: Color(0xFFEF5350),
  };
  static const _labels = {
    TaskPriority.low: 'Low',
    TaskPriority.medium: 'Medium',
    TaskPriority.high: 'High',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: TaskPriority.values.map((p) {
        final selected = p == priority;
        final color = _colors[p]!;
        return GestureDetector(
          onTap: () => onChanged(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _labels[p]!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({
    required this.selected,
    required this.onToggle,
    required this.color,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_weekdayOrder.length, (i) {
        final w = _weekdayOrder[i];
        final isSelected = selected.contains(w);
        return GestureDetector(
          onTap: () => onToggle(w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? color : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? color
                    : AppSemanticColors.subtleBorder(context),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                _weekdayLabels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : AppSemanticColors.textFaint(context),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _SubtaskEditor extends StatelessWidget {
  const _SubtaskEditor({
    required this.subtasks,
    required this.onToggle,
    required this.onRemove,
    required this.onEdit,
  });

  final List<SubTask> subtasks;
  final ValueChanged<int> onToggle;
  final ValueChanged<int> onRemove;
  final void Function(int index, String value) onEdit;

  @override
  Widget build(BuildContext context) {
    if (subtasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No subtasks yet — add steps below to break this task down.',
          style: TextStyle(
            fontSize: 12,
            color: AppSemanticColors.textFaint(context),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < subtasks.length; i++)
          _SubtaskRow(
            key: ValueKey(subtasks[i].id),
            subtask: subtasks[i],
            onToggle: () => onToggle(i),
            onRemove: () => onRemove(i),
            onEdit: (v) => onEdit(i, v),
          ),
      ],
    );
  }
}

class _SubtaskRow extends StatefulWidget {
  const _SubtaskRow({
    super.key,
    required this.subtask,
    required this.onToggle,
    required this.onRemove,
    required this.onEdit,
  });

  final SubTask subtask;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final ValueChanged<String> onEdit;

  @override
  State<_SubtaskRow> createState() => _SubtaskRowState();
}

class _SubtaskRowState extends State<_SubtaskRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.subtask.title);

  @override
  void didUpdateWidget(covariant _SubtaskRow old) {
    super.didUpdateWidget(old);
    if (old.subtask.title != widget.subtask.title &&
        _controller.text != widget.subtask.title) {
      _controller.text = widget.subtask.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.subtask.completed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Container(
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
                  color: done
                      ? AppSemanticColors.successGreen
                      : Colors.transparent,
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onEdit,
              style: TextStyle(
                fontSize: 14,
                color: done
                    ? AppSemanticColors.textFaint(context)
                    : AppSemanticColors.textStrong(context),
                decoration:
                    done ? TextDecoration.lineThrough : TextDecoration.none,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 16, color: AppSemanticColors.textFaint(context)),
            tooltip: 'Remove',
            onPressed: widget.onRemove,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
