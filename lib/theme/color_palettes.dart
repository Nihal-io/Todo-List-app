import 'package:flutter/material.dart';

/// Curated set of seed-color presets that drive Material 3's
/// `ColorScheme.fromSeed`. Add new entries at the end so persisted
/// preferences keep resolving correctly.
enum AppPalette {
  indigo,
  teal,
  rose,
  forest,
  sunset,
  slate,
  amber,
  plum;

  Color get seedColor {
    switch (this) {
      case AppPalette.indigo:
        return const Color(0xFF5C6BC0);
      case AppPalette.teal:
        return const Color(0xFF26A69A);
      case AppPalette.rose:
        return const Color(0xFFE91E63);
      case AppPalette.forest:
        return const Color(0xFF2E7D32);
      case AppPalette.sunset:
        return const Color(0xFFFF7043);
      case AppPalette.slate:
        return const Color(0xFF546E7A);
      case AppPalette.amber:
        return const Color(0xFFFFB300);
      case AppPalette.plum:
        return const Color(0xFF8E24AA);
    }
  }

  String get label {
    switch (this) {
      case AppPalette.indigo:
        return 'Indigo';
      case AppPalette.teal:
        return 'Teal';
      case AppPalette.rose:
        return 'Rose';
      case AppPalette.forest:
        return 'Forest';
      case AppPalette.sunset:
        return 'Sunset';
      case AppPalette.slate:
        return 'Slate';
      case AppPalette.amber:
        return 'Amber';
      case AppPalette.plum:
        return 'Plum';
    }
  }
}
