import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'providers/settings_provider.dart';
import 'providers/tasks_provider.dart';
import 'routing/router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the in-memory notification flag in lockstep with the persisted
    // setting. Done here (top-level) so the tasks notifier can read it
    // synchronously when scheduling reminders during CRUD operations.
    ref.listen<AsyncValue<AppSettings>>(settingsProvider, (prev, next) {
      final value = next.valueOrNull;
      if (value == null) return;
      final current = ref.read(notificationsEnabledProvider);
      if (current != value.notificationsEnabled) {
        ref.read(notificationsEnabledProvider.notifier).state =
            value.notificationsEnabled;
        // Apply downstream: schedule or cancel everything in one shot.
        unawaited(ref
            .read(tasksProvider.notifier)
            .applyNotificationsEnabled(value.notificationsEnabled));
      }
    });

    final asyncSettings = ref.watch(settingsProvider);

    // Block first paint until preferences load so the user does not see a
    // flash of the default theme when their persisted choice differs.
    return asyncSettings.when(
      loading: () => const _Bootstrap(),
      error: (_, __) => MaterialApp.router(
        title: 'Todo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: appRouter,
      ),
      data: (settings) {
        return MaterialApp.router(
          title: 'Todo',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: AppTheme.light(
            seedColor: settings.palette.seedColor,
            density: settings.density,
          ),
          darkTheme: AppTheme.dark(
            seedColor: settings.palette.seedColor,
            density: settings.density,
          ),
          routerConfig: appRouter,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.textScale.scaleFactor),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
