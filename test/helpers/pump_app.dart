import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/theme/app_theme.dart';

/// Widget-test harness (Step 22, theme added at Step 22a).
///
/// Every widget test pumps its widget through [PumpApp.pumpApp], so the
/// app-wide setup lives in one place: the light [AppTheme] (Q6), which the
/// app also uses whenever the platform isn't in dark mode.
///
/// Bloc providers are not added here. Each test wraps its widget in its own
/// `BlocProvider<…>.value` with a mock bloc (D19), because a generic
/// provider helper would hide which bloc a widget reads.
extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a [MaterialApp] themed with [AppTheme.light].
  ///
  /// The [Material] ancestor lets small widgets (chips, list tiles, buttons)
  /// be tested on their own, without a `Scaffold` of their own. Views that
  /// build their own `Scaffold` work the same way.
  Future<void> pumpApp(Widget widget) {
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Material(child: widget),
      ),
    );
  }
}
