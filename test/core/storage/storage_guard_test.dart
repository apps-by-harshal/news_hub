import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/storage/storage_guard.dart';

/// Fails with a real [TypeError], like a stored value of the wrong type.
Future<String> readWrongType() async {
  const Object stored = 42;
  return stored as String;
}

void main() {
  group('guardStorageCall', () {
    test('returns the value of a successful call', () async {
      expect(await guardStorageCall<String>(() async => 'value'), 'value');
    });

    test('turns a HiveError into a CacheException', () async {
      await expectLater(
        guardStorageCall<void>(
          () async => throw HiveError('Box has already been closed.'),
        ),
        throwsA(
          const CacheException(
            'Local storage failed: Box has already been closed.',
          ),
        ),
      );
    });

    test('also maps a HiveError thrown synchronously', () async {
      await expectLater(
        guardStorageCall<void>(() => throw HiveError('Box not found.')),
        throwsA(const CacheException('Local storage failed: Box not found.')),
      );
    });

    test('turns a TypeError into a CacheException', () async {
      await expectLater(
        guardStorageCall<String>(readWrongType),
        throwsA(
          isA<CacheException>().having(
            (CacheException e) => e.message,
            'message',
            startsWith('Unexpected stored value: '),
          ),
        ),
      );
    });

    test('keeps the original stack trace', () async {
      final StackTrace original = StackTrace.fromString('original trace');
      Object? caught;
      StackTrace? caughtTrace;

      try {
        await guardStorageCall<void>(
          () async => Error.throwWithStackTrace(HiveError('boom'), original),
        );
      } catch (error, stackTrace) {
        caught = error;
        caughtTrace = stackTrace;
      }

      expect(caught, const CacheException('Local storage failed: boom'));
      expect(caughtTrace.toString(), original.toString());
    });

    test('rethrows an AppException unchanged', () async {
      const NetworkException exception = NetworkException('offline');

      await expectLater(
        guardStorageCall<void>(() async => throw exception),
        throwsA(same(exception)),
      );
    });

    test('rethrows any other error unchanged', () async {
      final StateError error = StateError('init() not called');

      await expectLater(
        guardStorageCall<void>(() async => throw error),
        throwsA(same(error)),
      );
    });
  });
}
