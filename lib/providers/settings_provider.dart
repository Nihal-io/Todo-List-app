import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/task.dart';
import '../theme/color_palettes.dart';

const String _prefsKey = 'app_settings_v1';

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  SharedPreferences? _prefs;

  @override
  Future<AppSettings> build() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return AppSettings.defaults;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> _persist(AppSettings next) async {
    state = AsyncData(next);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_prefsKey, jsonEncode(next.toJson()));
  }

  AppSettings get _current => state.valueOrNull ?? AppSettings.defaults;

  /// Replace the entire settings object. Named `replaceAll` to avoid colliding
  /// with `AsyncNotifierBase.update`.
  Future<void> replaceAll(AppSettings next) => _persist(next);

  Future<void> setThemeMode(ThemeMode mode) =>
      _persist(_current.copyWith(themeMode: mode));

  Future<void> setPalette(AppPalette palette) =>
      _persist(_current.copyWith(palette: palette));

  Future<void> setTextScale(TextScalePref scale) =>
      _persist(_current.copyWith(textScale: scale));

  Future<void> setDensity(DensityPref density) =>
      _persist(_current.copyWith(density: density));

  Future<void> setFirstDayOfWeek(FirstDayOfWeekPref pref) =>
      _persist(_current.copyWith(firstDayOfWeek: pref));

  Future<void> setDateFormat(DateFormatPref pref) =>
      _persist(_current.copyWith(dateFormat: pref));

  Future<void> setShowProgressCard(bool value) =>
      _persist(_current.copyWith(showProgressCard: value));

  Future<void> setShowOverduePanel(bool value) =>
      _persist(_current.copyWith(showOverduePanel: value));

  Future<void> setShowSectionToggle(bool value) =>
      _persist(_current.copyWith(showSectionToggle: value));

  Future<void> setQuadrantColor(MatrixQuadrant quadrant, Color color) {
    final next = Map<MatrixQuadrant, Color>.from(
      _current.quadrantColorOverrides,
    )..[quadrant] = color;
    return _persist(_current.copyWith(quadrantColorOverrides: next));
  }

  Future<void> resetQuadrantColor(MatrixQuadrant quadrant) {
    final next = Map<MatrixQuadrant, Color>.from(
      _current.quadrantColorOverrides,
    )..remove(quadrant);
    return _persist(_current.copyWith(quadrantColorOverrides: next));
  }

  Future<void> resetAll() => _persist(AppSettings.defaults);
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Resolved settings synchronously — falls back to defaults while loading.
final resolvedSettingsProvider = Provider<AppSettings>((ref) {
  return ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
});

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(resolvedSettingsProvider).themeMode,
);

final seedColorProvider = Provider<Color>(
  (ref) => ref.watch(resolvedSettingsProvider).palette.seedColor,
);

final densityProvider = Provider<DensityPref>(
  (ref) => ref.watch(resolvedSettingsProvider).density,
);

final textScaleProvider = Provider<TextScalePref>(
  (ref) => ref.watch(resolvedSettingsProvider).textScale,
);

/// Resolved per-quadrant colors: defaults overlaid with any user overrides.
final quadrantColorsProvider = Provider<Map<MatrixQuadrant, Color>>((ref) {
  final overrides = ref.watch(resolvedSettingsProvider).quadrantColorOverrides;
  return {
    for (final q in MatrixQuadrant.values) q: overrides[q] ?? q.color,
  };
});

/// Convenience for reading a single quadrant's resolved color.
Color quadrantColorOf(WidgetRef ref, MatrixQuadrant quadrant) {
  return ref.watch(quadrantColorsProvider)[quadrant] ?? quadrant.color;
}
