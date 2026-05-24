import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/tasks_provider.dart';

const _compactMargin = EdgeInsets.fromLTRB(12, 0, 12, 12);

SnackBar _compactSnackBar({
  required String message,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  return SnackBar(
    content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: _compactMargin,
    action: action,
  );
}

void showTaskCompletedSnackBar(
  BuildContext context, {
  required Task task,
  required DateTime day,
  required bool recurring,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    _compactSnackBar(
      message: 'Completed "${task.title}"',
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          final container = ProviderScope.containerOf(context);
          final notifier = container.read(tasksProvider.notifier);
          if (recurring) {
            notifier.toggleForDay(task.id, day);
          } else {
            notifier.toggle(task.id);
          }
        },
      ),
    ),
  );
}

void showTaskCreatedSnackBar(BuildContext context, Task task) {
  ScaffoldMessenger.of(context).showSnackBar(
    _compactSnackBar(message: 'Task added'),
  );
}

void showSubtaskBlockedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    _compactSnackBar(message: 'Complete all subtasks first'),
  );
}

void showSubtaskAutoCompletedSnackBar(
  BuildContext context, {
  required Task task,
  required String subtaskId,
  required DateTime actionDay,
  required bool recurring,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    _compactSnackBar(
      message: 'Completed "${task.title}"',
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          final container = ProviderScope.containerOf(context);
          final notifier = container.read(tasksProvider.notifier);
          notifier.toggleSubtask(
            task.id,
            subtaskId,
            actionDay: actionDay,
          );
        },
      ),
    ),
  );
}
