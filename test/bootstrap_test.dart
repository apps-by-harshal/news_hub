import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/app.dart';
import 'package:news_hub/bootstrap.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/core/utils/bloc_observer.dart';
import 'package:news_hub/startup_error_app.dart';

import 'helpers/mocks.dart';

/// The global hooks `bootstrap` replaces.
///
/// Captured inside each test body (the test binding installs its own
/// `FlutterError.onError` after `setUp`) and restored right after
/// `bootstrap` returns, before any `expect`: flutter_test fails a test that
/// leaves `FlutterError.onError` changed.
final class _SavedGlobals {
  _SavedGlobals.capture()
    : blocObserver = Bloc.observer,
      onError = FlutterError.onError,
      presentError = FlutterError.presentError,
      platformOnError = PlatformDispatcher.instance.onError;

  final BlocObserver blocObserver;
  final FlutterExceptionHandler? onError;
  final FlutterExceptionHandler presentError;
  final bool Function(Object, StackTrace)? platformOnError;

  void restore() {
    Bloc.observer = blocObserver;
    FlutterError.onError = onError;
    FlutterError.presentError = presentError;
    PlatformDispatcher.instance.onError = platformOnError;
  }
}

void main() {
  late AppConfig config;
  late MockLocalDatabase localDatabase;
  late List<LogEvent> events;
  late LogCallback listener;

  /// Error-level events written through the real `AppLoggerImpl`.
  List<LogEvent> errorEvents() =>
      events.where((LogEvent event) => event.level == Level.error).toList();

  setUp(() {
    config = AppConfig.fromMap(const <String, String>{
      'FLAVOR': 'dev',
      'API_BASE_URL': 'https://newsapi.org/v2',
      'API_KEY': 'test-api-key',
      'ENABLE_HTTP_LOGGING': 'false',
      'LOG_LEVEL': 'debug',
    });
    localDatabase = MockLocalDatabase();
    when(() => localDatabase.init()).thenAnswer((_) async {});
    // logger 2.8.0 calls log listeners before its filter, for every event.
    events = <LogEvent>[];
    listener = events.add;
    Logger.addLogListener(listener);
  });

  tearDown(() async {
    Logger.removeLogListener(listener);
    await getIt.reset();
  });

  group('bootstrap', () {
    testWidgets('returns App, initialises storage once, logs no error and '
        'installs AppBlocObserver', (WidgetTester tester) async {
      final _SavedGlobals saved = _SavedGlobals.capture();

      final Object app = await bootstrap(
        config: config,
        localDatabase: localDatabase,
      );
      final BlocObserver installedObserver = Bloc.observer;
      saved.restore();

      expect(app, isA<App>());
      addTearDown((app as App).router.dispose);
      expect(installedObserver, isA<AppBlocObserver>());
      verify(() => localDatabase.init()).called(1);
      expect(errorEvents(), isEmpty);
    });

    testWidgets('returns StartupErrorApp and logs one error when storage '
        "can't be opened", (WidgetTester tester) async {
      final StateError failure = StateError('disk full');
      when(() => localDatabase.init())
          .thenAnswer((_) => Future<void>.error(failure));
      final _SavedGlobals saved = _SavedGlobals.capture();

      final Object app = await bootstrap(
        config: config,
        localDatabase: localDatabase,
      );
      final BlocObserver observerAfter = Bloc.observer;
      saved.restore();

      expect(app, isA<StartupErrorApp>());
      expect(observerAfter, same(saved.blocObserver));
      final List<LogEvent> errors = errorEvents();
      expect(errors, hasLength(1));
      expect(
        errors.single.message,
        'Startup failed: local storage could not be opened',
      );
      expect(errors.single.error, same(failure));
      expect(errors.single.stackTrace, isNotNull);
    });

    testWidgets('installs a FlutterError.onError that logs the error and '
        'still presents it', (WidgetTester tester) async {
      final _SavedGlobals saved = _SavedGlobals.capture();
      final StateError failure = StateError('layout broke');
      final StackTrace trace = StackTrace.current;
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: failure,
        stack: trace,
      );
      final List<FlutterErrorDetails> presented = <FlutterErrorDetails>[];

      final Object app = await bootstrap(
        config: config,
        localDatabase: localDatabase,
      );
      final FlutterExceptionHandler? installed = FlutterError.onError;
      FlutterError.presentError = presented.add;
      installed?.call(details);
      saved.restore();

      addTearDown((app as App).router.dispose);
      expect(installed, isNotNull);
      expect(identical(installed, saved.onError), isFalse);
      expect(presented, hasLength(1));
      expect(presented.single, same(details));
      final List<LogEvent> errors = errorEvents();
      expect(errors, hasLength(1));
      expect(errors.single.message, 'Uncaught Flutter framework error');
      expect(errors.single.error, same(failure));
      expect(errors.single.stackTrace, same(trace));
    });

    testWidgets('installs a PlatformDispatcher.onError that logs the error '
        'and reports it handled', (WidgetTester tester) async {
      final _SavedGlobals saved = _SavedGlobals.capture();
      final StateError failure = StateError('async boom');
      final StackTrace trace = StackTrace.current;

      final Object app = await bootstrap(
        config: config,
        localDatabase: localDatabase,
      );
      final bool Function(Object, StackTrace)? installed =
          PlatformDispatcher.instance.onError;
      final bool? handled = installed?.call(failure, trace);
      saved.restore();

      addTearDown((app as App).router.dispose);
      expect(installed, isNotNull);
      expect(handled, isTrue);
      final List<LogEvent> errors = errorEvents();
      expect(errors, hasLength(1));
      expect(errors.single.message, 'Uncaught platform error');
      expect(errors.single.error, same(failure));
      expect(errors.single.stackTrace, same(trace));
    });

    testWidgets('installs both error hooks even when storage fails', (
      WidgetTester tester,
    ) async {
      when(() => localDatabase.init())
          .thenAnswer((_) => Future<void>.error(StateError('disk full')));
      final _SavedGlobals saved = _SavedGlobals.capture();

      final Object app = await bootstrap(
        config: config,
        localDatabase: localDatabase,
      );
      final FlutterExceptionHandler? flutterHook = FlutterError.onError;
      final bool Function(Object, StackTrace)? platformHook =
          PlatformDispatcher.instance.onError;
      saved.restore();

      expect(app, isA<StartupErrorApp>());
      expect(flutterHook, isNotNull);
      expect(identical(flutterHook, saved.onError), isFalse);
      expect(platformHook, isNotNull);
      expect(identical(platformHook, saved.platformOnError), isFalse);
    });
  });
}
