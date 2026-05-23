import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/tasks_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.init();
  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProviderOverride(notifications),
      ],
      child: const App(),
    ),
  );
}
