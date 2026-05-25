import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/tasks_provider.dart';

const _compactMargin = EdgeInsets.fromLTRB(12, 0, 12, 12);

/// All snackbars in the app are one-second floating toasts with no action.
/// The visible row state (checkbox tick, strike-through, new row appearing)
/// is the real confirmation — these just nudge you that something happened.
SnackBar _compactSnackBar({required String message}) {
  return SnackBar(
    content: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
    duration: const Duration(seconds: 1),
    behavior: SnackBarBehavior.floating,
    margin: _compactMargin,
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
    _compactSnackBar(message: 'Completed "${task.title}"'),
  );
}

void showSubtaskBlockedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    _compactSnackBar(message: 'Complete all subtasks first'),
  );
}

/// Confirms with the user, then deletes the task. No snackbar — the dialog
/// itself is the safety net.
Future<void> confirmAndDeleteTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete task?'),
      content: Text('Remove "${task.title}"?'),
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
  if (confirmed != true) return;
  await ref.read(tasksProvider.notifier).remove(task.id);
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
    _compactSnackBar(message: 'Completed "${task.title}"'),
  );
}
