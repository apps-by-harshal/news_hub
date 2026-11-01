import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/search_articles.dart';

import '../../../../helpers/mocks.dart';

/// Builds [SearchArticlesParams] at runtime.
SearchArticlesParams buildParams({String query = 'flutter', int page = 2}) {
  return SearchArticlesParams(query: query, page: page);
}

/// Builds an empty [PaginatedArticles] for [page].
PaginatedArticles buildPage(int page) {
  return PaginatedArticles(
    items: const <Article>[],
    page: page,
    hasMore: true,
    isFromCache: false,
  );
}

/// Builds a `Failure` result at runtime, so the test does not depend on
/// whether the `Result` constructors are `const`.
Result<PaginatedArticles> networkFailure(String message) {
  return Failure<PaginatedArticles>(failures.NetworkFailure(message));
}

void main() {
  late MockNewsRepository repository;
  late SearchArticles searchArticles;

  setUp(() {
    repository = MockNewsRepository();
    searchArticles = SearchArticles(repository: repository);
  });

  group('SearchArticles', () {
    test(
      'forwards query and page to the repository and returns its Success',
      () async {
        final PaginatedArticles page = buildPage(2);
        when(() => repository.searchArticles(query: 'flutter', page: 2))
            .thenAnswer((_) async => Success<PaginatedArticles>(page));

        final Result<PaginatedArticles> result = await searchArticles(
          buildParams(),
        );

        expect(result, equals(Success<PaginatedArticles>(page)));
        verify(() => repository.searchArticles(query: 'flutter', page: 2))
            .called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    test('trims the query before forwarding it', () async {
      final PaginatedArticles page = buildPage(1);
      when(() => repository.searchArticles(query: 'dart news', page: 1))
          .thenAnswer((_) async => Success<PaginatedArticles>(page));

      final Result<PaginatedArticles> result = await searchArticles(
        buildParams(query: '  dart news \n', page: 1),
      );

      expect(result, equals(Success<PaginatedArticles>(page)));
      verify(() => repository.searchArticles(query: 'dart news', page: 1))
          .called(1);
      verifyNoMoreInteractions(repository);
    });

    test('returns the repository Failure unchanged', () async {
      when(() => repository.searchArticles(query: 'flutter', page: 2))
          .thenAnswer((_) async => networkFailure('offline'));

      final Result<PaginatedArticles> result = await searchArticles(
        buildParams(),
      );

      expect(result, equals(networkFailure('offline')));
      verify(() => repository.searchArticles(query: 'flutter', page: 2))
          .called(1);
      verifyNoMoreInteractions(repository);
    });
  });

  group('SearchArticlesParams', () {
    test('equal when every field is equal', () {
      final SearchArticlesParams a = buildParams();
      final SearchArticlesParams b = buildParams();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when query differs', () {
      expect(buildParams(query: 'dart'), isNot(equals(buildParams())));
    });

    test('not equal when page differs', () {
      expect(buildParams(page: 3), isNot(equals(buildParams())));
    });

    test('props lists query, then page', () {
      final SearchArticlesParams params = buildParams(query: 'dart', page: 4);

      expect(params.props, <Object?>['dart', 4]);
    });

    test('query must not be empty or whitespace only', () {
      expect(() => buildParams(query: ''), throwsA(isA<AssertionError>()));
      expect(() => buildParams(query: ' \t\n'), throwsA(isA<AssertionError>()));
    });

    test('page must be at least 1', () {
      expect(() => buildParams(page: 0), throwsA(isA<AssertionError>()));
    });
  });
}
