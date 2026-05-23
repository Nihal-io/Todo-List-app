import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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

// ---------------------------------------------------------------------------

// Weekday chip order: Sun Mon Tue Wed Thu Fri Sat
// DateTime.weekday: 1=Mon ... 7=Sun → store as those ints
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

  TaskKind _kind = TaskKind.task;
  late DateTime _startDate;
  DateTime? _endDate;
  MatrixQuadrant _quadrant = kDefaultQuadrant;
  TaskPriority _priority = TaskPriority.medium;

  final Set<int> _weekdays = <int>{};
  bool _repeatForever = true;
  DateTime? _repeatUntil;

  @override
  void initState() {
    super.initState();
    final task = widget.taskToEdit;
    if (task != null) {
      _titleController.text = task.title;
      _kind = task.kind;
      _startDate = task.startDate;
      _endDate = task.endDate;
      _quadrant = task.quadrant;
      _priority = task.priority;
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
      lastDate: DateTime(2030),
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
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _repeatUntil = picked;
        _repeatForever = false;
      });
    }
  }

  void _clearEndDate() => setState(() => _endDate = null);

  void _toggleWeekday(int w) => setState(() {
        if (_weekdays.contains(w)) {
          _weekdays.remove(w);
        } else {
          _weekdays.add(w);
        }
      });

  void _submit() {
    if (!_canSubmit) return;
    final title = _titleController.text.trim();
    final id = widget.taskToEdit?.id ?? _uuid.v4();

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
      );
    }

    if (_isEditing) {
      ref.read(tasksProvider.notifier).update(task);
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
