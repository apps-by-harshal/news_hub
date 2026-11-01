import 'package:flutter/material.dart';

/// The app's Material 3 themes, both generated from one seed colour.
///
/// Widgets read colours and text styles from `Theme.of(context)`
/// (`colorScheme` / `textTheme`), never from this class directly, so a theme
/// change applies everywhere (CLAUDE.md §4.6).
abstract final class AppTheme {
  /// The brand colour every colour scheme is generated from.
  static const Color seedColor = Color(0xFF1565C0);

  /// The light theme, used by default and in widget tests.
  static ThemeData get light => _build(Brightness.light);

  /// The dark theme, used when the platform asks for dark mode.
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
    );
  }
}
