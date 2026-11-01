import 'package:flutter/material.dart';
import 'package:news_hub/core/theme/app_theme.dart';
import 'package:news_hub/core/widgets/app_error_view.dart';

/// The app shown instead of `App` when local storage can't be opened at
/// startup (Step 23, Q3 A).
///
/// `bootstrap` logs the failure and returns this widget. It has no Retry:
/// a second `initDependencies` would register the get_it types again and
/// throw, so the user is asked to restart the app instead. It uses the same
/// title and themes as `App` (D21) but has no router.
class StartupErrorApp extends StatelessWidget {
  /// Creates the startup error app.
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News Hub',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(
        body: AppErrorView(
          message:
              "Couldn't open storage on this device. Please restart the app.",
        ),
      ),
    );
  }
}
