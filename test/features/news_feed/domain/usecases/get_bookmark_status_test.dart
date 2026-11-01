import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';

import '../../../../helpers/mocks.dart';

/// Builds a `Success` result at runtime, so the test does not depend on
/// whether the `Result` constructors are `const`.
Result<bool> success(bool value) => Success<bool>(value);

/// Builds a `Failure` result at runtime, for the same reason.
Result<bool> cacheFailure(String message) {
  return Failure<bool>(failures.CacheFailure(message));
}

void main() {
  late MockNewsRepository repository;
  late GetBookmarkStatus getBookmarkStatus;

  setUp(() {
    repository = MockNewsRepository();
    getBookmarkStatus = GetBookmarkStatus(repository: repository);
  });

  group('GetBookmarkStatus', () {
    test('returns Success(true) when the article is bookmarked', () async {
      when(() => repository.isBookmarked('https://example.com/a'))
          .thenAnswer((_) async => success(true));

      final Result<bool> result = await getBookmarkStatus(
        'https://example.com/a',
      );

      expect(result, equals(success(true)));
      verify(() => repository.isBookmarked('https://example.com/a')).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns Success(false) when the article is not bookmarked', () async {
      when(() => repository.isBookmarked('https://example.com/b'))
          .thenAnswer((_) async => success(false));

      final Result<bool> result = await getBookmarkStatus(
        'https://example.com/b',
      );

      expect(result, equals(success(false)));
      verify(() => repository.isBookmarked('https://example.com/b')).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns the repository Failure unchanged', () async {
      when(() => repository.isBookmarked('https://example.com/c'))
          .thenAnswer((_) async => cacheFailure('box closed'));

      final Result<bool> result = await getBookmarkStatus(
        'https://example.com/c',
      );

      expect(result, equals(cacheFailure('box closed')));
      verify(() => repository.isBookmarked('https://example.com/c')).called(1);
      verifyNoMoreInteractions(repository);
    });
  });
}
