import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import '../shared/date_utils.dart';
import 'reminder_selection.dart';

/// True only on a native Android runtime — safe to call on web/desktop.
bool get _isAndroidNative =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Outcome of checking / requesting Android notification permissions.
class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsEnabled;

  bool get allGranted => notificationsEnabled && exactAlarmsEnabled;

  /// Human-readable issues for SnackBars / dialogs.
  List<String> get issues {
    final out = <String>[];
    if (!notificationsEnabled) {
      out.add('Notifications are blocked — enable them in system settings.');
    }
    if (!exactAlarmsEnabled) {
      out.add(
        'Alarms & reminders are off — turn them on so tasks fire on time '
        '(Settings → Apps → Todo → Alarms & reminders).',
      );
    }
    return out;
  }
}

/// Android-focused wrapper around `flutter_local_notifications`. Handles
/// initialisation, permission requests, persistent scheduling via
/// [zonedSchedule], and a foreground service that surfaces today's tasks.
///
/// All operations are wrapped in try/catch and treated as best-effort —
/// notifications failing to schedule should never crash the app or block
/// the user from saving tasks.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _reminderChannelId = 'todo_list_reminders';
  static const String _reminderChannelName = 'Task reminders';
  static const String _reminderChannelDescription =
      'Heads-up when a scheduled task or event is due.';

  static const String _foregroundChannelId = 'todo_list_foreground';
  static const String _foregroundChannelName = 'Today\'s tasks';
  static const String _foregroundChannelDescription =
      'Keeps reminders alive and shows what is due today.';

  /// Foreground service notification id — must not be 0 and kept separate
  /// from per-task reminder ids.
  static const int _foregroundNotificationId = 888888;

  /// How many future occurrences to queue for recurring tasks.
  static const int _maxRecurringOccurrences = 24;

  bool _initialised = false;
  bool _supported = true;
  bool _foregroundRunning = false;

  /// Called when the user taps a task reminder — used to queue the next
  /// occurrence for recurring tasks.
  void Function(String taskId)? onTaskReminderFired;

  bool get isSupported => _supported;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    if (!_isAndroidNative) {
      _supported = false;
      return;
    }
    try {
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
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      if (_isAndroidNative) {
        await _configureLocalTimeZone();
        final androidImpl = _android;
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _reminderChannelId,
            _reminderChannelName,
            description: _reminderChannelDescription,
            importance: Importance.high,
          ),
        );
        await androidImpl?.createNotificationChannel(
          const AndroidNotificationChannel(
            _foregroundChannelId,
            _foregroundChannelName,
            description: _foregroundChannelDescription,
            importance: Importance.low,
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

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    onTaskReminderFired?.call(payload);
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Reads current permission state without prompting.
  Future<NotificationPermissionStatus> checkPermissions() async {
    if (!_supported || !_isAndroidNative) {
      return const NotificationPermissionStatus(
        notificationsEnabled: true,
        exactAlarmsEnabled: true,
      );
    }
    try {
      final notifications = await _android?.areNotificationsEnabled();
      final exact = await _android?.canScheduleExactNotifications();
      return NotificationPermissionStatus(
        notificationsEnabled: notifications ?? true,
        exactAlarmsEnabled: exact ?? true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.checkPermissions failed: $e');
      }
      return const NotificationPermissionStatus(
        notificationsEnabled: false,
        exactAlarmsEnabled: false,
      );
    }
  }

  /// Requests missing permissions, then returns the final state.
  Future<NotificationPermissionStatus> ensurePermissions() async {
    if (!_supported || !_isAndroidNative) {
      return const NotificationPermissionStatus(
        notificationsEnabled: true,
        exactAlarmsEnabled: true,
      );
    }
    try {
      await _android?.requestNotificationsPermission();
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.ensurePermissions failed: $e');
      }
    }
    return checkPermissions();
  }

  /// Asks the OS for notification permission. Safe to call repeatedly.
  Future<bool> requestPermission() async {
    final status = await ensurePermissions();
    return status.notificationsEnabled;
  }

  /// Requests exact-alarm permission required for [zonedSchedule] on Android 12+.
  Future<bool> requestExactAlarmPermission() async {
    final status = await ensurePermissions();
    return status.exactAlarmsEnabled;
  }

  /// Maps a task's stable id to an int notification id.
  int _notificationIdFor(String key) => key.hashCode & 0x7FFFFFFF;

  int _occurrenceNotificationId(String taskId, DateTime fireAt) =>
      _notificationIdFor('$taskId@${fireAt.millisecondsSinceEpoch}');

  /// Cancels every pending notification whose payload matches [taskId].
  Future<void> cancelForTask(String taskId) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(_notificationIdFor(taskId));
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        if (p.payload == taskId) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (_) {}
  }

  /// Rebuilds alarms for [tasks]: today's pending items, or top upcoming when
  /// nothing is due today. No-op when [enabled] is false.
  Future<void> scheduleRemindersForAll(
    List<Task> tasks, {
    bool enabled = true,
  }) async {
    if (!_supported || !enabled) return;
    final targets = tasksForScheduledReminders(tasks);
    final targetIds = targets.map((t) => t.id).toSet();

    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload;
        if (payload == null || payload.isEmpty) continue;
        if (p.id == _foregroundNotificationId) continue;
        if (!targetIds.contains(payload)) {
          await _plugin.cancel(p.id);
        }
      }
    } catch (_) {}

    for (final task in targets) {
      await scheduleForTask(task, enabled: true);
    }
  }

  /// (Re)schedules the next occurrence(s) for [task]. Recurring tasks queue
  /// several future alarms so they keep firing without reopening the app.
  Future<void> scheduleForTask(Task task, {bool enabled = true}) async {
    if (!_supported) return;
    await cancelForTask(task.id);
    if (!enabled) return;

    if (task.isRecurring) {
      await _scheduleRecurringOccurrences(task);
      return;
    }

    if (task.completed) return;
    final fireAt = task.nextReminderAfter(DateTime.now());
    if (fireAt == null) return;
    if (!fireAt.isAfter(DateTime.now())) return;

    await _scheduleOneShot(
      id: _notificationIdFor(task.id),
      task: task,
      fireAt: fireAt,
    );
  }

  Future<void> _scheduleRecurringOccurrences(Task task) async {
    var cursor = DateTime.now();
    var scheduled = 0;

    while (scheduled < _maxRecurringOccurrences) {
      final fireAt = task.nextReminderAfter(cursor);
      if (fireAt == null) break;

      final now = DateTime.now();
      if (!fireAt.isAfter(now.subtract(const Duration(seconds: 30)))) {
        cursor = fireAt.add(const Duration(minutes: 1));
        continue;
      }

      await _scheduleOneShot(
        id: _occurrenceNotificationId(task.id, fireAt),
        task: task,
        fireAt: fireAt,
      );
      scheduled++;
      cursor = fireAt.add(const Duration(minutes: 1));
    }
  }

  Future<void> _scheduleOneShot({
    required int id,
    required Task task,
    required DateTime fireAt,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        task.title,
        _bodyFor(task, fireAt),
        tz.TZDateTime.from(fireAt, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannelId,
            _reminderChannelName,
            channelDescription: _reminderChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: task.id,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService._scheduleOneShot failed: $e');
      }
    }
  }

  String _bodyFor(Task task, DateTime fireAt) {
    final today = dateOnly(DateTime.now());
    final fireDay = dateOnly(fireAt);
    final dayLabel = sameDay(fireDay, today)
        ? 'today'
        : sameDay(fireDay, today.add(const Duration(days: 1)))
            ? 'tomorrow'
            : '${fireDay.month}/${fireDay.day}';

    if (task.isEvent) {
      if (task.startTime != null) {
        return 'Event on $dayLabel at ${task.startTime!.formatTwelveHour()}';
      }
      return 'Event on $dayLabel';
    }
    return task.startTime == null
        ? 'Due $dayLabel'
        : 'Due $dayLabel at ${task.startTime!.formatTwelveHour()}';
  }

  /// Cancels all scheduled task reminders. The foreground-service notification
  /// is restored afterwards if it was running.
  Future<void> cancelAll() async {
    if (!_supported) return;
    final restoreForeground = _foregroundRunning;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    if (restoreForeground) {
      _foregroundRunning = false;
    }
  }

  /// Starts or updates the Android foreground service. Only call when reminders
  /// are enabled — use [stopTodayForeground] when they are off.
  Future<void> updateTodayForeground(List<Task> tasks, [DateTime? day]) async {
    if (!_supported || !_isAndroidNative) return;

    final summary = foregroundSummaryFor(tasks, day ?? DateTime.now());

    const details = AndroidNotificationDetails(
      _foregroundChannelId,
      _foregroundChannelName,
      channelDescription: _foregroundChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: false,
    );

    try {
      await _android?.startForegroundService(
        _foregroundNotificationId,
        summary.title,
        summary.body,
        notificationDetails: details,
        foregroundServiceTypes: {
          AndroidServiceForegroundType.foregroundServiceTypeSpecialUse,
        },
      );
      _foregroundRunning = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService.updateTodayForeground failed: $e');
      }
    }
  }

  Future<void> stopTodayForeground() async {
    if (!_supported || !_isAndroidNative) return;
    try {
      await _android?.stopForegroundService();
    } catch (_) {}
    _foregroundRunning = false;
  }
}
