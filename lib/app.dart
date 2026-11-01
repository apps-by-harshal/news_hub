import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:news_hub/core/theme/app_theme.dart';

/// The root widget of News Hub (Step 22a).
///
/// Applies the light and dark [AppTheme]s (the platform picks one,
/// `ThemeMode.system`) and hands navigation to [router]. The router is built
/// and disposed by the caller (`bootstrap.dart`, Step 23), so tests can pass
/// their own. No global bloc providers: each page creates its own bloc (D19).
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
