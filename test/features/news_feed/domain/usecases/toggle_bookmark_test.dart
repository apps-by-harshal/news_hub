import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';

import '../../../../helpers/mocks.dart';

/// Builds an [Article] at runtime that differs only by [url].
///
/// [sourceName] is a parameter so the nested `ArticleSource` is never
/// const-eligible (agreement 9, and keeps `prefer_const_constructors` quiet).
Article buildArticle(String url, {String sourceName = 'BBC News'}) {
  return Article(
    url: url,
    title: 'Headline',
    source: ArticleSource(id: null, name: sourceName),
    publishedAt: DateTime.utc(2026, 10, 30, 9),
    author: null,
    description: null,
    content: null,
    imageUrl: null,
  );
}

/// Builds a `Success` result at runtime, so the test does not depend on
/// whether the `Result` constructors are `const`.
Result<bool> success(bool value) => Success<bool>(value);

/// Builds a `Failure` result at runtime, for the same reason.
Result<bool> cacheFailure(String message) {
  return Failure<bool>(failures.CacheFailure(message));
}

void main() {
  late MockNewsRepository repository;
  late ToggleBookmark toggleBookmark;

  setUp(() {
    repository = MockNewsRepository();
    toggleBookmark = ToggleBookmark(repository: repository);
  });

  group('ToggleBookmark', () {
    test('returns Success(true) when the article is now bookmarked', () async {
      final Article article = buildArticle('https://example.com/a');
      when(() => repository.toggleBookmark(article))
          .thenAnswer((_) async => success(true));

      final Result<bool> result = await toggleBookmark(article);

      expect(result, equals(success(true)));
      verify(() => repository.toggleBookmark(article)).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns Success(false) when the bookmark was removed', () async {
      final Article article = buildArticle('https://example.com/b');
      when(() => repository.toggleBookmark(article))
          .thenAnswer((_) async => success(false));

      final Result<bool> result = await toggleBookmark(article);

      expect(result, equals(success(false)));
      verify(() => repository.toggleBookmark(article)).called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns the repository Failure unchanged', () async {
      final Article article = buildArticle('https://example.com/c');
      when(() => repository.toggleBookmark(article))
          .thenAnswer((_) async => cacheFailure('disk full'));

      final Result<bool> result = await toggleBookmark(article);

      expect(result, equals(cacheFailure('disk full')));
      verify(() => repository.toggleBookmark(article)).called(1);
      verifyNoMoreInteractions(repository);
    });
  });
}
