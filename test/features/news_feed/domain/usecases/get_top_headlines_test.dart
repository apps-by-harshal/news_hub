import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';

import '../../../../helpers/mocks.dart';

/// Builds [GetTopHeadlinesParams] at runtime (agreement 9).
GetTopHeadlinesParams buildParams({
  NewsCategory category = NewsCategory.business,
  int page = 2,
  bool forceRefresh = true,
}) {
  return GetTopHeadlinesParams(
    category: category,
    page: page,
    forceRefresh: forceRefresh,
  );
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
  late GetTopHeadlines getTopHeadlines;

  setUp(() {
    repository = MockNewsRepository();
    getTopHeadlines = GetTopHeadlines(repository: repository);
  });

  group('GetTopHeadlines', () {
    test(
      'forwards every param to the repository and returns its Success',
      () async {
        final PaginatedArticles page = buildPage(2);
        when(
          () => repository.getTopHeadlines(
            category: NewsCategory.business,
            page: 2,
            forceRefresh: true,
          ),
        ).thenAnswer((_) async => Success<PaginatedArticles>(page));

        final Result<PaginatedArticles> result = await getTopHeadlines(
          buildParams(),
        );

        expect(result, equals(Success<PaginatedArticles>(page)));
        verify(
          () => repository.getTopHeadlines(
            category: NewsCategory.business,
            page: 2,
            forceRefresh: true,
          ),
        ).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    test('returns the repository Failure unchanged', () async {
      when(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).thenAnswer((_) async => networkFailure('offline'));

      final Result<PaginatedArticles> result = await getTopHeadlines(
        buildParams(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      );

      expect(result, equals(networkFailure('offline')));
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    });
  });

  group('GetTopHeadlinesParams', () {
    test('equal when every field is equal', () {
      final GetTopHeadlinesParams a = buildParams();
      final GetTopHeadlinesParams b = buildParams();

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('not equal when category differs', () {
      expect(
        buildParams(category: NewsCategory.sports),
        isNot(equals(buildParams())),
      );
    });

    test('not equal when page differs', () {
      expect(buildParams(page: 3), isNot(equals(buildParams())));
    });

    test('not equal when forceRefresh differs', () {
      expect(buildParams(forceRefresh: false), isNot(equals(buildParams())));
    });

    test('props lists category, page, then forceRefresh', () {
      final GetTopHeadlinesParams params = buildParams(
        category: NewsCategory.health,
        page: 4,
        forceRefresh: false,
      );

      expect(params.props, <Object?>[NewsCategory.health, 4, false]);
    });

    test('page must be at least 1', () {
      expect(() => buildParams(page: 0), throwsA(isA<AssertionError>()));
    });
  });
}
