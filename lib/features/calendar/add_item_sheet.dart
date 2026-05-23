import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/task.dart';
import '../../providers/selected_day_provider.dart';
import '../../providers/tasks_provider.dart';

const _uuid = Uuid();

void showAddItemSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AddItemSheet(),
  );
}

// ---------------------------------------------------------------------------

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

const List<Color> _kPalette = [
  Color(0xFF5C6BC0), // indigo (default)
  Color(0xFFEF5350), // red
  Color(0xFFFF7043), // orange
  Color(0xFFFFB300), // amber
  Color(0xFF66BB6A), // green
  Color(0xFF26A69A), // teal
  Color(0xFF42A5F5), // sky blue
  Color(0xFFAB47BC), // purple
];

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _titleController = TextEditingController();
  late DateTime _startDate;
  DateTime? _endDate;
  Color _color = kDefaultTaskColor;
  TaskPriority _priority = TaskPriority.medium;

  @override
  void initState() {
    super.initState();
    _startDate = ref.read(selectedCalendarDayProvider);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
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
        // If the existing end date is now before the new start, clear it.
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = null;
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
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _clearEndDate() => setState(() => _endDate = null);

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    ref.read(tasksProvider.notifier).add(Task(
          id: _uuid.v4(),
          title: title,
          startDate: _startDate,
          endDate: _endDate,
          priority: _priority,
          color: _color,
        ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final startLabel =
        '${months[_startDate.month - 1]} ${_startDate.day}, ${_startDate.year}';
    final endLabel = _endDate == null
        ? 'Until… (single day)'
        : '${months[_endDate!.month - 1]} ${_endDate!.day}, ${_endDate!.year}';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Task name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              const _SectionLabel('Color'),
              const SizedBox(height: 8),
              _ColorPicker(
                color: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 16),

              const _SectionLabel('Priority'),
              const SizedBox(height: 8),
              _PriorityPicker(
                priority: _priority,
                onChanged: (p) => setState(() => _priority = p),
              ),
              const SizedBox(height: 16),

              const _SectionLabel('When'),
              const SizedBox(height: 8),
              _PickerRow(
                icon: Icons.calendar_today_outlined,
                label: startLabel,
                primary: primary,
                onTap: _pickStartDate,
              ),
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
                        color: const Color(0xFF9090A8),
                        onPressed: _clearEndDate,
                        tooltip: 'Make single-day',
                      ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
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
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF9090A8),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A2E)),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.color, required this.onChanged});

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _kPalette.map((c) {
        final selected = c.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.5),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker(
      {required this.priority, required this.onChanged});

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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? color
                  : color.withValues(alpha: 0.1),
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
