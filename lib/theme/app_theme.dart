import 'package:flutter/material.dart';

import '../models/app_settings.dart';

class AppTheme {
  AppTheme._();

  static const Color _defaultSeed = Color(0xFF5C6BC0); // Indigo 400

  /// Surfaces, typography, etc. used by the *light* palette.
  static const Color _lightScaffold = Color(0xFFF8F9FA);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextStrong = Color(0xFF1A1A2E);
  static const Color _lightTextBody = Color(0xFF3D3D5C);
  static const Color _lightTextMuted = Color(0xFF6B6B8A);
  static const Color _lightTextFaint = Color(0xFF9090A8);
  static const Color _lightInputFill = Color(0xFFF0F0F7);

  /// Surfaces, typography, etc. used by the *dark* palette.
  static const Color _darkScaffold = Color(0xFF0F0F18);
  static const Color _darkSurface = Color(0xFF1A1A28);
  static const Color _darkTextStrong = Color(0xFFF2F2F7);
  static const Color _darkTextBody = Color(0xFFD0D0DC);
  static const Color _darkTextMuted = Color(0xFFA0A0B8);
  static const Color _darkTextFaint = Color(0xFF80809A);
  static const Color _darkInputFill = Color(0xFF252535);
  static const Color _darkDivider = Color(0xFF2A2A3A);

  static ThemeData light({
    Color seedColor = _defaultSeed,
    DensityPref density = DensityPref.comfortable,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: _lightSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: density.visualDensity,
      scaffoldBackgroundColor: _lightScaffold,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightScaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _lightTextStrong,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: _lightTextStrong),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: Colors.white,
        elevation: 8,
        shadowColor: Color(0x1A000000),
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _lightTextStrong,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _lightTextStrong,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightTextStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _lightTextStrong,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _lightTextBody,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _lightTextMuted,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _lightTextFaint,
          letterSpacing: 0.2,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  static ThemeData dark({
    Color seedColor = _defaultSeed,
    DensityPref density = DensityPref.comfortable,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: _darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: density.visualDensity,
      scaffoldBackgroundColor: _darkScaffold,
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkDivider),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkScaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _darkTextStrong,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: _darkTextStrong),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: _darkSurface,
        elevation: 8,
        shadowColor: Color(0x80000000),
        padding: EdgeInsets.symmetric(horizontal: 8),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _darkTextStrong,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _darkTextStrong,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkTextStrong,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _darkTextStrong,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _darkTextBody,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _darkTextMuted,
        ),
        labelMedium: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _darkTextFaint,
          letterSpacing: 0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkDivider,
        thickness: 1,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkInputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

/// Theme-aware semantic colors used by hand-built tiles, panels, and badges
/// across the app. Centralised so dark mode adjusts in lock-step with light.
class AppSemanticColors {
  AppSemanticColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Background for the elevated tiles & cards we draw by hand.
  static Color tileBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1F1F2E) : Colors.white;

  /// Border between cards / dividers used inline.
  static Color tileBorder(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A3A) : Colors.grey.shade200;

  /// Background of unfilled checkbox / muted chip backdrops.
  static Color subtleSurface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF252535) : const Color(0xFFF0F0F7);

  /// Outline of unfilled checkboxes, inactive nav pills, etc.
  static Color subtleBorder(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3A3A50) : const Color(0xFFD0D0E0);

  static Color textStrong(BuildContext context) => _isDark(context)
      ? const Color(0xFFF2F2F7)
      : const Color(0xFF1A1A2E);

  static Color textBody(BuildContext context) => _isDark(context)
      ? const Color(0xFFD0D0DC)
      : const Color(0xFF3D3D5C);

  static Color textMuted(BuildContext context) => _isDark(context)
      ? const Color(0xFFA0A0B8)
      : const Color(0xFF6B6B8A);

  static Color textFaint(BuildContext context) => _isDark(context)
      ? const Color(0xFF80809A)
      : const Color(0xFF9090A8);

  /// Used on the bottom nav for inactive items.
  static Color navInactive(BuildContext context) => _isDark(context)
      ? const Color(0xFF80809A)
      : const Color(0xFFB0B0C8);

  /// Faint background tint behind progress bars, etc.
  static Color trackBackground(BuildContext context) => _isDark(context)
      ? const Color(0xFF2A2A3A)
      : const Color(0xFFEDEDF5);

  /// Soft elevated shadow color appropriate to the brightness.
  static Color softShadow(BuildContext context) => _isDark(context)
      ? Colors.black.withValues(alpha: 0.4)
      : Colors.black.withValues(alpha: 0.04);

  /// "Done" green — same hue in both modes.
  static const Color successGreen = Color(0xFF66BB6A);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color dangerRed = Color(0xFFEF5350);
}
