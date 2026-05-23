import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme/color_palettes.dart';
import 'task.dart';

enum TextScalePref { small, medium, large }

enum DensityPref { compact, comfortable, spacious }

enum FirstDayOfWeekPref { sunday, monday }

enum DateFormatPref { monthDay, dayMonth, slash }

extension TextScalePrefX on TextScalePref {
  double get scaleFactor {
    switch (this) {
      case TextScalePref.small:
        return 0.9;
      case TextScalePref.medium:
        return 1.0;
      case TextScalePref.large:
        return 1.15;
    }
  }

  String get label {
    switch (this) {
      case TextScalePref.small:
        return 'Small';
      case TextScalePref.medium:
        return 'Default';
      case TextScalePref.large:
        return 'Large';
    }
  }
}

extension DensityPrefX on DensityPref {
  /// Padding multiplier for hand-built task tiles.
  double get paddingMultiplier {
    switch (this) {
      case DensityPref.compact:
        return 0.8;
      case DensityPref.comfortable:
        return 1.0;
      case DensityPref.spacious:
        return 1.25;
    }
  }

  VisualDensity get visualDensity {
    switch (this) {
      case DensityPref.compact:
        return VisualDensity.compact;
      case DensityPref.comfortable:
        return VisualDensity.standard;
      case DensityPref.spacious:
        return VisualDensity.comfortable;
    }
  }

  String get label {
    switch (this) {
      case DensityPref.compact:
        return 'Compact';
      case DensityPref.comfortable:
        return 'Comfortable';
      case DensityPref.spacious:
        return 'Spacious';
    }
  }
}

extension FirstDayOfWeekPrefX on FirstDayOfWeekPref {
  StartingDayOfWeek get startingDayOfWeek {
    switch (this) {
      case FirstDayOfWeekPref.sunday:
        return StartingDayOfWeek.sunday;
      case FirstDayOfWeekPref.monday:
        return StartingDayOfWeek.monday;
    }
  }

  String get label {
    switch (this) {
      case FirstDayOfWeekPref.sunday:
        return 'Sunday';
      case FirstDayOfWeekPref.monday:
        return 'Monday';
    }
  }
}

extension DateFormatPrefX on DateFormatPref {
  String get label {
    switch (this) {
      case DateFormatPref.monthDay:
        return 'May 23';
      case DateFormatPref.dayMonth:
        return '23 May';
      case DateFormatPref.slash:
        return '23/05';
    }
  }
}

/// Immutable bag of every user-tunable preference. Persisted as JSON via
/// `SharedPreferences`.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.palette = AppPalette.indigo,
    this.textScale = TextScalePref.medium,
    this.density = DensityPref.comfortable,
    this.firstDayOfWeek = FirstDayOfWeekPref.sunday,
    this.dateFormat = DateFormatPref.monthDay,
    this.showProgressCard = true,
    this.showOverduePanel = true,
    this.showSectionToggle = true,
    this.quadrantColorOverrides = const <MatrixQuadrant, Color>{},
  });

  final ThemeMode themeMode;
  final AppPalette palette;
  final TextScalePref textScale;
  final DensityPref density;
  final FirstDayOfWeekPref firstDayOfWeek;
  final DateFormatPref dateFormat;

  final bool showProgressCard;
  final bool showOverduePanel;
  final bool showSectionToggle;

  /// Per-quadrant color overrides. Missing entries fall back to the
  /// `MatrixQuadrant.color` default.
  final Map<MatrixQuadrant, Color> quadrantColorOverrides;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    AppPalette? palette,
    TextScalePref? textScale,
    DensityPref? density,
    FirstDayOfWeekPref? firstDayOfWeek,
    DateFormatPref? dateFormat,
    bool? showProgressCard,
    bool? showOverduePanel,
    bool? showSectionToggle,
    Map<MatrixQuadrant, Color>? quadrantColorOverrides,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      palette: palette ?? this.palette,
      textScale: textScale ?? this.textScale,
      density: density ?? this.density,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      dateFormat: dateFormat ?? this.dateFormat,
      showProgressCard: showProgressCard ?? this.showProgressCard,
      showOverduePanel: showOverduePanel ?? this.showOverduePanel,
      showSectionToggle: showSectionToggle ?? this.showSectionToggle,
      quadrantColorOverrides:
          quadrantColorOverrides ?? this.quadrantColorOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'palette': palette.name,
        'textScale': textScale.name,
        'density': density.name,
        'firstDayOfWeek': firstDayOfWeek.name,
        'dateFormat': dateFormat.name,
        'showProgressCard': showProgressCard,
        'showOverduePanel': showOverduePanel,
        'showSectionToggle': showSectionToggle,
        'quadrantColorOverrides': {
          for (final e in quadrantColorOverrides.entries)
            e.key.name: _colorToHex(e.value),
        },
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: _enumByName(ThemeMode.values, json['themeMode']) ??
          ThemeMode.system,
      palette: _enumByName(AppPalette.values, json['palette']) ??
          AppPalette.indigo,
      textScale: _enumByName(TextScalePref.values, json['textScale']) ??
          TextScalePref.medium,
      density: _enumByName(DensityPref.values, json['density']) ??
          DensityPref.comfortable,
      firstDayOfWeek:
          _enumByName(FirstDayOfWeekPref.values, json['firstDayOfWeek']) ??
              FirstDayOfWeekPref.sunday,
      dateFormat: _enumByName(DateFormatPref.values, json['dateFormat']) ??
          DateFormatPref.monthDay,
      showProgressCard: json['showProgressCard'] as bool? ?? true,
      showOverduePanel: json['showOverduePanel'] as bool? ?? true,
      showSectionToggle: json['showSectionToggle'] as bool? ?? true,
      quadrantColorOverrides: _decodeQuadrantOverrides(
        json['quadrantColorOverrides'],
      ),
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return null;
}

String _colorToHex(Color c) {
  final argb = c.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color? _hexToColor(String? hex) {
  if (hex == null) return null;
  var clean = hex.trim();
  if (clean.startsWith('#')) clean = clean.substring(1);
  if (clean.length == 6) clean = 'FF$clean';
  if (clean.length != 8) return null;
  final value = int.tryParse(clean, radix: 16);
  if (value == null) return null;
  return Color(value);
}

Map<MatrixQuadrant, Color> _decodeQuadrantOverrides(Object? raw) {
  if (raw is! Map) return const <MatrixQuadrant, Color>{};
  final out = <MatrixQuadrant, Color>{};
  raw.forEach((key, value) {
    final q = _enumByName(MatrixQuadrant.values, key);
    final c = _hexToColor(value is String ? value : null);
    if (q != null && c != null) out[q] = c;
  });
  return out;
}
