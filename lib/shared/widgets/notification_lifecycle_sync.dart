import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tasks_provider.dart';

/// Refreshes scheduled reminders when the app returns to the foreground.
class NotificationLifecycleSync extends ConsumerStatefulWidget {
  const NotificationLifecycleSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationLifecycleSync> createState() =>
      _NotificationLifecycleSyncState();
}

class _NotificationLifecycleSyncState
    extends ConsumerState<NotificationLifecycleSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.read(tasksProvider.notifier).refreshNotifications();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
