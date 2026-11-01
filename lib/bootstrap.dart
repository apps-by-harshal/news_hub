import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/app.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/router/router_observer.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/core/utils/bloc_observer.dart';
import 'package:news_hub/router/app_router.dart';
import 'package:news_hub/startup_error_app.dart';

/// Wires the app together and returns the root widget for `runApp`.
///
/// Called once by `main.dart`, which reads [config] with
/// `AppConfig.fromEnvironment()`. Registers every dependency in the global
/// `getIt` (the pages read their use cases from it) and initialises storage
/// through `initDependencies`. Then, using the registered `AppLogger`:
///
/// - installs `FlutterError.onError` (logs at error level, then still calls
///   `FlutterError.presentError`) and `PlatformDispatcher.instance.onError`
///   (logs at error level and reports the error handled);
/// - sets `Bloc.observer` to an [AppBlocObserver];
/// - returns [App] with a router that logs navigation ([AppRouterObserver]).
///
/// If storage can't be opened, the failure is logged, the error hooks are
/// still installed, and [StartupErrorApp] is returned instead (Step 23, Q3 A).
/// Only `LocalDatabase.init()` can fail here: registration runs first, so
/// the logger is always available. [localDatabase] replaces the real
/// database in tests.
Future<Widget> bootstrap({
  required AppConfig config,
  LocalDatabase? localDatabase,
}) async {
  try {
    await initDependencies(config: config, localDatabase: localDatabase);
  } on Object catch (error, stackTrace) {
    final AppLogger logger = getIt<AppLogger>();
    _installErrorHooks(logger);
    logger.error(
      'Startup failed: local storage could not be opened',
      error: error,
      stackTrace: stackTrace,
    );
    return const StartupErrorApp();
  }

  final AppLogger logger = getIt<AppLogger>();
  _installErrorHooks(logger);
  Bloc.observer = AppBlocObserver(logger: logger);
  return App(
    router: createAppRouter(
      observers: <NavigatorObserver>[AppRouterObserver(logger: logger)],
    ),
  );
}

/// Routes uncaught framework and platform errors to [logger].
void _installErrorHooks(AppLogger logger) {
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      'Uncaught Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    logger.error(
      'Uncaught platform error',
      error: error,
      stackTrace: stackTrace,
    );
    return true;
  };
}
