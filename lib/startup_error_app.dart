import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_error_view.dart';

/// The app shown instead of `App` when local storage can't be opened at
/// startup.
///
/// `bootstrap` logs the failure and returns this widget. It has no Retry:
/// a second `initDependencies` would register the get_it types again and
/// throw, so the user is asked to restart the app instead. It uses the same
/// title and themes as `App` but has no router.
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
