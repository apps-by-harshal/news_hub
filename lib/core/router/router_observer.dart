import 'package:flutter/widgets.dart';

import '../logging/app_logger.dart';

/// Logs navigation through [AppLogger] at debug level.
///
/// Only route **names** are logged, never `RouteSettings.arguments` or a
/// router's `extra`: those can carry whole entities (the article page gets
/// its `Article` as `extra`). A missing route is logged as `none`, a route
/// without a name as `unnamed`.
///
/// Overrides take `Route<Object?>` instead of `Route<dynamic>`: the two are
/// the same type for overriding, and the project allows no `dynamic`.
final class AppRouterObserver extends NavigatorObserver {
  /// Creates an observer that writes to the given `logger`.
  AppRouterObserver({required this._logger});

  final AppLogger _logger;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    _logger.debug(
      'Route pushed: ${_nameOf(route)} (previous: ${_nameOf(previousRoute)})',
    );
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    _logger.debug(
      'Route popped: ${_nameOf(route)} (previous: ${_nameOf(previousRoute)})',
    );
  }

  @override
  void didRemove(Route<Object?> route, Route<Object?>? previousRoute) {
    _logger.debug(
      'Route removed: ${_nameOf(route)} (previous: ${_nameOf(previousRoute)})',
    );
  }

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    _logger.debug(
      'Route replaced: ${_nameOf(oldRoute)} → ${_nameOf(newRoute)}',
    );
  }

  static String _nameOf(Route<Object?>? route) {
    if (route == null) {
      return 'none';
    }
    return route.settings.name ?? 'unnamed';
  }
}
