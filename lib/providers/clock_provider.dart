import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide source of truth for the current time.
///
/// Polls `DateTime.now()` once per minute (cheap, sufficient for day-grain
/// urgency) and pokes itself awake whenever the app returns to the
/// foreground. Reading [DateTime.now()] directly elsewhere bypasses this
/// reactive layer — prefer watching [clockProvider] or [todayProvider].
///
/// Backward clock movement is supported: every tick reads the current
/// system time, so a user (or test) winding the device clock back will
/// cause downstream providers to recompute against the earlier instant.
class _ClockNotifier extends StateNotifier<DateTime>
    with WidgetsBindingObserver {
  _ClockNotifier() : super(DateTime.now()) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
  }

  Timer? _timer;

  void _tick() {
    if (!mounted) return;
    state = DateTime.now();
  }

  /// Forces an immediate clock read. Used internally on resume; exposed
  /// so foreground events (e.g. a navigation revisit) can refresh state
  /// without waiting for the next minute boundary.
  void poke() => _tick();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final clockProvider = StateNotifierProvider<_ClockNotifier, DateTime>(
  (ref) => _ClockNotifier(),
);

/// Day-only projection of [clockProvider]. Updates only when the day
/// boundary is crossed, so widgets watching it don't rebuild every minute.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider);
  return DateTime(now.year, now.month, now.day);
});
