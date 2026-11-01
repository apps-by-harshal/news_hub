import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';

/// The root widget of News Hub.
///
/// Applies the light and dark [AppTheme]s (the platform picks one,
/// `ThemeMode.system`) and hands navigation to [router]. The router is built
/// and disposed by the caller (`bootstrap.dart`), so tests can pass
/// their own. No global bloc providers: each page creates its own bloc.
class App extends StatelessWidget {
  /// Creates the app around [router].
  const App({required this.router, super.key});

  /// The router that decides which page is shown.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'News Hub',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
