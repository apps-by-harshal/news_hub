import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/logging/app_logger.dart';

/// Logs every bloc's lifecycle through the injected [AppLogger].
///
/// Installed once in `bootstrap.dart` with `Bloc.observer = …` (Step 23).
///
/// - [onCreate] / [onClose] → `debug('Bloc created|closed: <BlocType>')`.
/// - [onTransition] → `debug('<BlocType>: <EventType> | <From> → <To>')`.
/// - [onError] → `error('<BlocType> failed', error:, stackTrace:)`.
///
/// Only runtime types are logged, never values: states hold whole article
/// lists, and events can carry entities. `onEvent` and `onChange` are not
/// logged, because every transition already names its event and both states
/// (CLAUDE.md §4.3, D19). Overrides declare `Object?` where the framework
/// declares `dynamic` (CLAUDE.md §4.1).
final class AppBlocObserver extends BlocObserver {
  /// Creates an observer that writes to [logger].
  const AppBlocObserver({required this._logger});

  final AppLogger _logger;

  @override
  void onCreate(BlocBase<Object?> bloc) {
    super.onCreate(bloc);
    _logger.debug('Bloc created: ${bloc.runtimeType}');
  }

  @override
  void onTransition(
    Bloc<Object?, Object?> bloc,
    Transition<Object?, Object?> transition,
  ) {
    super.onTransition(bloc, transition);
    _logger.debug(
      '${bloc.runtimeType}: ${transition.event.runtimeType} | '
      '${transition.currentState.runtimeType} → '
      '${transition.nextState.runtimeType}',
    );
  }

  @override
  void onError(BlocBase<Object?> bloc, Object error, StackTrace stackTrace) {
    _logger.error(
      '${bloc.runtimeType} failed',
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onClose(BlocBase<Object?> bloc) {
    super.onClose(bloc);
    _logger.debug('Bloc closed: ${bloc.runtimeType}');
  }
}
