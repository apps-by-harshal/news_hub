import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/utils/failure_message.dart';

/// Diagnostic text that must never reach the user (D9). Built at runtime so
/// the failures under test are not `const` (agreement 9).
String diagnosticFor(String name) =>
    'diagnostic: $name failed in the data layer';

/// One failure of every type, each with its own diagnostic message.
List<failures.Failure> buildOneOfEachFailure() => <failures.Failure>[
  failures.ServerFailure(diagnosticFor('server'), statusCode: 503),
  failures.UnauthorizedFailure(diagnosticFor('unauthorized')),
  failures.NetworkFailure(diagnosticFor('network')),
  failures.CacheFailure(diagnosticFor('cache')),
  failures.UnexpectedFailure(diagnosticFor('unexpected')),
];

void main() {
  group('FailureMessage.userMessage', () {
    test('ServerFailure → the service is having trouble', () {
      final failures.Failure failure = failures.ServerFailure(
        diagnosticFor('server'),
        statusCode: 503,
      );

      expect(
        failure.userMessage,
        'The news service is having trouble. Please try again later.',
      );
    });

    test('UnauthorizedFailure → the API key was rejected', () {
      final failures.Failure failure = failures.UnauthorizedFailure(
        diagnosticFor('unauthorized'),
      );

      expect(
        failure.userMessage,
        "The news service rejected the app's API key.",
      );
    });

    test('NetworkFailure → offline, check the connection', () {
      final failures.Failure failure = failures.NetworkFailure(
        diagnosticFor('network'),
      );

      expect(
        failure.userMessage,
        "You're offline. Check your connection and try again.",
      );
    });

    test('CacheFailure → device storage problem', () {
      final failures.Failure failure = failures.CacheFailure(
        diagnosticFor('cache'),
      );

      expect(failure.userMessage, "Couldn't read or save data on this device.");
    });

    test('UnexpectedFailure → generic copy', () {
      final failures.Failure failure = failures.UnexpectedFailure(
        diagnosticFor('unexpected'),
      );

      expect(failure.userMessage, 'Something went wrong. Please try again.');
    });

    test('ServerFailure copy does not depend on the status code', () {
      final String withoutStatus = failures.ServerFailure(
        diagnosticFor('server'),
      ).userMessage;
      final String tooManyRequests = failures.ServerFailure(
        diagnosticFor('server'),
        statusCode: 429,
      ).userMessage;
      final String internalError = failures.ServerFailure(
        diagnosticFor('server'),
        statusCode: 500,
      ).userMessage;

      expect(tooManyRequests, withoutStatus);
      expect(internalError, withoutStatus);
    });

    test('never contains the diagnostic message (D9)', () {
      for (final failures.Failure failure in buildOneOfEachFailure()) {
        expect(
          failure.userMessage,
          isNot(contains(failure.message)),
          reason: '${failure.runtimeType} must not show its message',
        );
        expect(
          failure.userMessage,
          isNot(contains('diagnostic')),
          reason: '${failure.runtimeType} must not show diagnostic text',
        );
      }
    });

    test('every failure type has its own copy', () {
      final Set<String> messages = <String>{
        for (final failures.Failure failure in buildOneOfEachFailure())
          failure.userMessage,
      };

      expect(messages, hasLength(5));
    });
  });
}
