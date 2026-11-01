import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('seedColor is the News Hub blue', () {
      expect(AppTheme.seedColor, const Color(0xFF1565C0));
    });

    test('light is a Material 3 light theme built from the seed', () {
      final ThemeData theme = AppTheme.light;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(
        theme.colorScheme,
        ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
      );
    });

    test('dark is a Material 3 dark theme built from the seed', () {
      final ThemeData theme = AppTheme.dark;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(
        theme.colorScheme,
        ColorScheme.fromSeed(
          seedColor: AppTheme.seedColor,
          brightness: Brightness.dark,
        ),
      );
    });

    test('light and dark use different colour schemes', () {
      expect(AppTheme.light.colorScheme, isNot(AppTheme.dark.colorScheme));
      expect(
        AppTheme.light.colorScheme.surface,
        isNot(AppTheme.dark.colorScheme.surface),
      );
    });
  });
}
