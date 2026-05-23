import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'providers/settings_provider.dart';
import 'routing/router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(settingsProvider);

    // Block first paint until preferences load so the user does not see a
    // flash of the default theme when their persisted choice differs.
    return asyncSettings.when(
      loading: () => const _SettingsBootstrap(),
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

class _SettingsBootstrap extends StatelessWidget {
  const _SettingsBootstrap();

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
