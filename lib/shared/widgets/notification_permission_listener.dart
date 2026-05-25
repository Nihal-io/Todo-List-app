import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notification_service.dart';

/// Set to a [NotificationPermissionStatus] to surface a SnackBar once.
final notificationPermissionCheckProvider =
    StateProvider<NotificationPermissionStatus?>((ref) => null);

/// Shows a SnackBar when one or more Android notification permissions are
/// still denied after the user enabled reminders in Settings.
void showNotificationPermissionSnackBar(
  BuildContext context,
  NotificationPermissionStatus status,
) {
  if (status.allGranted) return;
  final text = status.issues.join('\n');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    ),
  );
}

/// Listens for permission checks triggered via [notificationPermissionCheckProvider].
class NotificationPermissionListener extends ConsumerWidget {
  const NotificationPermissionListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<NotificationPermissionStatus?>(
      notificationPermissionCheckProvider,
      (prev, next) {
        if (next == null || next.allGranted) return;
        showNotificationPermissionSnackBar(context, next);
        ref.read(notificationPermissionCheckProvider.notifier).state = null;
      },
    );
    return child;
  }
}
