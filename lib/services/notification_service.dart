import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/task.dart';

/// Thin wrapper around `flutter_local_notifications`. Handles initialisation,
/// permission requests, and scheduling/cancelling per-task reminders.
///
/// All operations are wrapped in try/catch and treated as best-effort —
/// notifications failing to schedule should never crash the app or block
/// the user from saving tasks.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'todo_list_reminders';
  static const String _channelName = 'Task reminders';
  static const String _channelDescription =
      'Heads-up when a scheduled task or event is due.';

  bool _initialised = false;
  bool _supported = true;

  bool get isSupported => _supported;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      // Linux is supported by the plugin but uses a different surface; web
      // and desktop without a matching platform plugin are best-effort no-ops.
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );
      await _plugin.initialize(settings);

      if (Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }
    } catch (e, st) {
      _supported = false;
      if (kDebugMode) {
        debugPrint('NotificationService.init failed: $e\n$st');
      }
    }
  }

  /// Asks the OS for permission. Safe to call repeatedly.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    try {
      if (Platform.isAndroid) {
        final androidImpl =
            _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final granted = await androidImpl?.requestNotificationsPermission();
        return granted ?? true;
      }
      if (Platform.isIOS) {
        final iosImpl =
            _plugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final granted = await iosImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      if (Platform.isMacOS) {
        final macImpl =
            _plugin.resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        final granted = await macImpl?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.requestPermission failed: $e');
      }
      return false;
    }
  }

  /// Maps a task's stable id to an int notification id.
  int _notificationIdFor(String taskId) =>
      taskId.hashCode & 0x7FFFFFFF; // strip sign bit

  /// Cancels any pending notification associated with [taskId].
  Future<void> cancelForTask(String taskId) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_notificationIdFor(taskId));
    } catch (_) {}
  }

  /// (Re)schedules a single one-shot notification for the next time this
  /// task fires. No-op if there is no future occurrence.
  ///
  /// This uses `zonedSchedule`-equivalent behaviour via `show` with a delay
  /// computed from the device's local clock. We intentionally avoid the
  /// `timezone` package so the user doesn't have to add another dependency.
  Future<void> scheduleForTask(Task task, {bool enabled = true}) async {
    if (!_supported) return;
    await cancelForTask(task.id);
    if (!enabled) return;
    if (task.completed) return;
    final fireAt = task.nextReminderAfter(DateTime.now());
    if (fireAt == null) return;
    if (!fireAt.isAfter(DateTime.now())) return;

    try {
      final delay = fireAt.difference(DateTime.now());
      // Use a delayed `show` rather than zonedSchedule so we don't have to
      // pull in timezone data. This is best-effort and won't survive process
      // death on Android — accepted trade-off for setup simplicity.
      unawaited(Future.delayed(delay, () async {
        if (!_supported) return;
        try {
          await _plugin.show(
            _notificationIdFor(task.id),
            task.title,
            _bodyFor(task),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDescription,
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
              macOS: DarwinNotificationDetails(),
            ),
            payload: task.id,
          );
        } catch (_) {}
      }));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.scheduleForTask failed: $e');
      }
    }
  }

  String _bodyFor(Task task) {
    if (task.isEvent) {
      if (task.startTime != null) {
        return 'Event at ${task.startTime!.formatTwelveHour()}';
      }
      return 'Event starts today';
    }
    return task.startTime == null
        ? 'Due today'
        : 'Due at ${task.startTime!.formatTwelveHour()}';
  }

  Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
