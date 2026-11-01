import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/router/router_observer.dart';

import '../../helpers/mocks.dart';

/// A bare [Route] with the given settings: the observer only reads
/// `settings`, so no widget, navigator or binding is needed.
class _TestRoute extends Route<Object?> {
  _TestRoute(String? name, {Object? arguments})
    : super(
        settings: RouteSettings(name: name, arguments: arguments),
      );
}

void main() {
  late MockAppLogger logger;
  late AppRouterObserver observer;

  setUp(() {
    logger = MockAppLogger();
    observer = AppRouterObserver(logger: logger);
  });

  group('AppRouterObserver', () {
    test('didPush logs the pushed route and the route below it', () {
      observer.didPush(_TestRoute('article'), _TestRoute('feed'));

      verify(() => logger.debug('Route pushed: article (previous: feed)'))
          .called(1);
      verifyNoMoreInteractions(logger);
    });

    test('didPush of the first route logs "none" as the previous route', () {
      observer.didPush(_TestRoute('feed'), null);

      verify(() => logger.debug('Route pushed: feed (previous: none)'))
          .called(1);
      verifyNoMoreInteractions(logger);
    });

    test('didPop logs the popped route and the route shown again', () {
      observer.didPop(_TestRoute('article'), _TestRoute('feed'));

      verify(() => logger.debug('Route popped: article (previous: feed)'))
          .called(1);
      verifyNoMoreInteractions(logger);
    });

    test('didRemove logs the removed route and the route below it', () {
      observer.didRemove(_TestRoute('article'), _TestRoute('feed'));

      verify(() => logger.debug('Route removed: article (previous: feed)'))
          .called(1);
      verifyNoMoreInteractions(logger);
    });

    test('didReplace logs the old and the new route', () {
      observer.didReplace(
        newRoute: _TestRoute('article'),
        oldRoute: _TestRoute('feed'),
      );

      verify(() => logger.debug('Route replaced: feed → article')).called(1);
      verifyNoMoreInteractions(logger);
    });

    test('didReplace without routes logs "none" for both', () {
      observer.didReplace();

      verify(() => logger.debug('Route replaced: none → none')).called(1);
      verifyNoMoreInteractions(logger);
    });

    test('a route without a name is logged as "unnamed"', () {
      observer.didPush(_TestRoute(null), _TestRoute('feed'));

      verify(() => logger.debug('Route pushed: unnamed (previous: feed)'))
          .called(1);
      verifyNoMoreInteractions(logger);
    });

    test('route arguments are never logged', () {
      const String secret = 'article-extra-must-not-be-logged';

      observer.didPush(
        _TestRoute('article', arguments: secret),
        _TestRoute('feed', arguments: <String, String>{'q': secret}),
      );

      final String message =
          verify(() => logger.debug(captureAny())).captured.single as String;
      expect(message, 'Route pushed: article (previous: feed)');
      expect(message, isNot(contains(secret)));
      verifyNoMoreInteractions(logger);
    });
  });
}
