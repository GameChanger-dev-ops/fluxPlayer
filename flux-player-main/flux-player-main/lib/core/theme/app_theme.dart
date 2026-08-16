import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';

enum FluxThemeMode { dark, amoled, light }

enum FluxAccent { indigo, amber, teal, rose, emerald }

abstract final class FluxTheme {
  static Color accentColor(FluxAccent accent) => switch (accent) {
        FluxAccent.indigo => FluxColors.indigo,
        FluxAccent.amber => FluxColors.amber,
        FluxAccent.teal => FluxColors.teal,
        FluxAccent.rose => FluxColors.rose,
        FluxAccent.emerald => FluxColors.emerald,
      };

  static ThemeData of(FluxThemeMode mode, FluxAccent accent) {
    final seed = accentColor(accent);
    return switch (mode) {
      FluxThemeMode.dark => _dark(seed, FluxColors.background),
      FluxThemeMode.amoled => _dark(seed, FluxColors.amoledBackground),
      FluxThemeMode.light => _light(seed),
    };
  }

  static ThemeData _dark(Color accent, Color background) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: FluxColors.amber,
        surface: FluxColors.surface,
        surfaceContainerHighest: FluxColors.surfaceElevated,
        error: FluxColors.error,
      ),
      scaffoldBackgroundColor: background,
      textTheme: FluxTypography.textTheme(
          FluxColors.textPrimary, FluxColors.textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData _light(Color accent) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: FluxColors.amber,
        surface: FluxColors.lightSurface,
        error: FluxColors.error,
      ),
      scaffoldBackgroundColor: FluxColors.lightBackground,
      textTheme: FluxTypography.textTheme(
          FluxColors.textMuted, FluxColors.textSecondary),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
