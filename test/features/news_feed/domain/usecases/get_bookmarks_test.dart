import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/usecase/usecase.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';

/// Builds a `Success` result at runtime, so the test does not depend on
/// whether the `Result` constructors are `const`.
Result<List<Article>> success(List<Article> articles) {
  return Success<List<Article>>(articles);
}

/// Builds a `Failure` result at runtime, for the same reason.
Result<List<Article>> cacheFailure(String message) {
  return Failure<List<Article>>(failures.CacheFailure(message));
}

void main() {
  late MockNewsRepository repository;
  late GetBookmarks getBookmarks;

  setUp(() {
    repository = MockNewsRepository();
    getBookmarks = GetBookmarks(repository: repository);
  });

  group('GetBookmarks', () {
    test('returns the repository bookmarks unchanged, in order', () async {
      final List<Article> bookmarks = <Article>[
        buildArticle('https://example.com/newest'),
        buildArticleWithoutOptionals('https://example.com/oldest'),
      ];
      when(() => repository.getBookmarks())
          .thenAnswer((_) async => success(bookmarks));

      final Result<List<Article>> result = await getBookmarks(const NoParams());

      expect(result, equals(success(bookmarks)));
      verify(() => repository.getBookmarks()).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns an empty list when nothing is bookmarked', () async {
      when(() => repository.getBookmarks())
          .thenAnswer((_) async => success(<Article>[]));

      final Result<List<Article>> result = await getBookmarks(const NoParams());

      expect(result, equals(success(<Article>[])));
      verify(() => repository.getBookmarks()).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns the repository Failure unchanged', () async {
      when(() => repository.getBookmarks())
          .thenAnswer((_) async => cacheFailure('box closed'));

      final Result<List<Article>> result = await getBookmarks(const NoParams());

      expect(result, equals(cacheFailure('box closed')));
      verify(() => repository.getBookmarks()).called(1);
      verifyNoMoreInteractions(repository);
    });
  });
}
