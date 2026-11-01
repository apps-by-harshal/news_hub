import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/utils/bloc_observer.dart';

import '../../helpers/mocks.dart';

/// The only event of [_CounterBloc].
final class _Increment {}

/// A tiny bloc whose states are plain ints, so a log line that leaked a
/// state value would contain a digit.
final class _CounterBloc extends Bloc<_Increment, int> {
  _CounterBloc() : super(0) {
    on<_Increment>((_Increment event, Emitter<int> emit) => emit(state + 1));
  }

  /// Exposes the protected [addError] to the tests.
  void fail(Object error, StackTrace stackTrace) => addError(error, stackTrace);
}

void main() {
  late MockAppLogger logger;
  late BlocObserver previousObserver;
  late _CounterBloc bloc;

  setUp(() {
    logger = MockAppLogger();
    previousObserver = Bloc.observer;
    // Set before the bloc is built, so it is used whether a bloc reads
    // Bloc.observer once at construction or on every call.
    Bloc.observer = AppBlocObserver(logger: logger);
    bloc = _CounterBloc();
  });

  tearDown(() async {
    if (!bloc.isClosed) {
      await bloc.close();
    }
    Bloc.observer = previousObserver;
  });

  group('AppBlocObserver', () {
    test('logs a bloc being created, once, at debug level', () {
      verify(() => logger.debug('Bloc created: _CounterBloc')).called(1);
      verifyNoMoreInteractions(logger);
    });

    test('logs each transition with runtime types only and nothing for the '
        'event or the change on their own', () async {
      final Future<int> next = bloc.stream.first;
      bloc.add(_Increment());
      await next;

      expect(bloc.state, 1);
      verifyInOrder(<void Function()>[
        () => logger.debug('Bloc created: _CounterBloc'),
        () => logger.debug('_CounterBloc: _Increment | int → int'),
      ]);
      verifyNoMoreInteractions(logger);
    });

    test('logs an error at error level with the error and stack trace', () {
      final StateError failure = StateError('boom');
      final StackTrace trace = StackTrace.current;

      bloc.fail(failure, trace);

      verify(
        () => logger.error(
          '_CounterBloc failed',
          error: failure,
          stackTrace: trace,
        ),
      ).called(1);
      verify(() => logger.debug('Bloc created: _CounterBloc')).called(1);
      verifyNoMoreInteractions(logger);
    });

    test('logs a bloc being closed, once, at debug level', () async {
      await bloc.close();

      verifyInOrder(<void Function()>[
        () => logger.debug('Bloc created: _CounterBloc'),
        () => logger.debug('Bloc closed: _CounterBloc'),
      ]);
      verifyNoMoreInteractions(logger);
    });

    test('is installed as a BlocObserver', () {
      expect(Bloc.observer, isA<BlocObserver>());
      expect(Bloc.observer, isA<AppBlocObserver>());
    });
  });
}
