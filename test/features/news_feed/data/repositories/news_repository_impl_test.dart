import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/data/repositories/news_repository_impl.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';

/// The message of the `NetworkFailure` returned when the device reports no
/// connection (spelled out here, not imported, so a change is deliberate).
const String offlineMessage = 'No network connection';

/// Builds [count] distinct articles whose URLs start with [prefix].
List<Article> buildArticles(String prefix, int count) {
  return List<Article>.generate(
    count,
    (int index) => buildArticle('https://example.com/$prefix-$index'),
  );
}

/// Builds a remote page at runtime.
RemoteArticlesPage buildRemotePage(
  List<Article> articles, {
  int totalResults = 38,
}) {
  return RemoteArticlesPage(articles: articles, totalResults: totalResults);
}

/// Builds the expected domain page at runtime.
PaginatedArticles buildPage(
  List<Article> items, {
  required int page,
  required bool hasMore,
  required bool isFromCache,
}) {
  return PaginatedArticles(
    items: items,
    page: page,
    hasMore: hasMore,
    isFromCache: isFromCache,
  );
}

/// `Result` values are built through functions, so the tests do not depend
/// on whether the `Result` constructors are `const`.
Result<PaginatedArticles> pageSuccess(PaginatedArticles page) {
  return Success<PaginatedArticles>(page);
}

Result<PaginatedArticles> pageFailure(failures.Failure failure) {
  return Failure<PaginatedArticles>(failure);
}

Result<bool> boolSuccess({required bool value}) {
  return Success<bool>(value);
}

Result<bool> boolFailure(failures.Failure failure) {
  return Failure<bool>(failure);
}

Result<List<Article>> listSuccess(List<Article> articles) {
  return Success<List<Article>>(articles);
}

Result<List<Article>> listFailure(failures.Failure failure) {
  return Failure<List<Article>>(failure);
}

void main() {
  late MockNewsRemoteDataSource remote;
  late MockNewsLocalDataSource local;
  late MockNetworkInfo networkInfo;
  late MockAppLogger logger;
  late NewsRepositoryImpl repository;

  setUp(() {
    remote = MockNewsRemoteDataSource();
    local = MockNewsLocalDataSource();
    networkInfo = MockNetworkInfo();
    logger = MockAppLogger();
    repository = NewsRepositoryImpl(
      remoteDataSource: remote,
      localDataSource: local,
      networkInfo: networkInfo,
      logger: logger,
    );
  });

  // ---- shorthands for the exact calls the repository should make ----

  void stubConnected({required bool connected}) {
    when(() => networkInfo.isConnected).thenAnswer((_) async => connected);
  }

  /// The page size is the literal 20, which pins `AppConstants.newsPageSize`.
  Future<RemoteArticlesPage> remoteHeadlines({
    NewsCategory category = NewsCategory.business,
    int page = 1,
    bool forceRefresh = false,
  }) {
    return remote.getTopHeadlines(
      category: category,
      page: page,
      pageSize: 20,
      forceRefresh: forceRefresh,
    );
  }

  Future<RemoteArticlesPage> remoteSearch({
    String query = 'flutter',
    int page = 1,
  }) {
    return remote.searchArticles(query: query, page: page, pageSize: 20);
  }

  Future<void> cacheHeadlines(
    List<Article> articles, {
    NewsCategory category = NewsCategory.business,
    int page = 1,
  }) {
    return local.cacheTopHeadlines(
      category: category,
      page: page,
      articles: articles,
    );
  }

  Future<List<Article>> cachedHeadlines({
    NewsCategory category = NewsCategory.business,
  }) {
    return local.getCachedTopHeadlines(category);
  }

  Future<Result<PaginatedArticles>> getHeadlines({
    NewsCategory category = NewsCategory.business,
    int page = 1,
    bool forceRefresh = false,
  }) {
    return repository.getTopHeadlines(
      category: category,
      page: page,
      forceRefresh: forceRefresh,
    );
  }

  Future<Result<PaginatedArticles>> search({
    String query = 'flutter',
    int page = 1,
  }) {
    return repository.searchArticles(query: query, page: page);
  }

  void verifyNoMoreCalls() {
    verifyNoMoreInteractions(remote);
    verifyNoMoreInteractions(local);
    verifyNoMoreInteractions(networkInfo);
    verifyNoMoreInteractions(logger);
  }

  group('getTopHeadlines', () {
    group('online', () {
      test(
        'fetches page 1, caches it, and returns it as not from cache',
        () async {
          final List<Article> articles = buildArticles('a', 3);
          stubConnected(connected: true);
          when(remoteHeadlines)
              .thenAnswer((_) async => buildRemotePage(articles));
          when(() => cacheHeadlines(articles)).thenAnswer((_) async {});

          final Result<PaginatedArticles> result = await getHeadlines();

          expect(
            result,
            pageSuccess(
              buildPage(articles, page: 1, hasMore: true, isFromCache: false),
            ),
          );
          verifyInOrder(<Object? Function()>[
            () => networkInfo.isConnected,
            remoteHeadlines,
            () => cacheHeadlines(articles),
          ]);
          verifyNoMoreCalls();
        },
      );

      test('passes the category and forceRefresh through unchanged', () async {
        final List<Article> articles = buildArticles('t', 2);
        stubConnected(connected: true);
        when(
          () => remoteHeadlines(
            category: NewsCategory.technology,
            forceRefresh: true,
          ),
        ).thenAnswer((_) async => buildRemotePage(articles));
        when(() => cacheHeadlines(articles, category: NewsCategory.technology))
            .thenAnswer((_) async {});

        final Result<PaginatedArticles> result = await getHeadlines(
          category: NewsCategory.technology,
          forceRefresh: true,
        );

        expect(
          result,
          pageSuccess(
            buildPage(articles, page: 1, hasMore: true, isFromCache: false),
          ),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          () => remoteHeadlines(
            category: NewsCategory.technology,
            forceRefresh: true,
          ),
          () => cacheHeadlines(articles, category: NewsCategory.technology),
        ]);
        verifyNoMoreCalls();
      });

      test('caches page 2 as page 2 and returns page 2', () async {
        final List<Article> articles = buildArticles('p2', 2);
        stubConnected(connected: true);
        when(() => remoteHeadlines(page: 2))
            .thenAnswer((_) async => buildRemotePage(articles));
        when(() => cacheHeadlines(articles, page: 2)).thenAnswer((_) async {});

        final Result<PaginatedArticles> result = await getHeadlines(page: 2);

        expect(
          result,
          pageSuccess(
            buildPage(articles, page: 2, hasMore: false, isFromCache: false),
          ),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          () => remoteHeadlines(page: 2),
          () => cacheHeadlines(articles, page: 2),
        ]);
        verifyNoMoreCalls();
      });

      group('hasMore = page * 20 < min(totalResults, 100)', () {
        const List<(int, int, bool)> cases = <(int, int, bool)>[
          (1, 38, true),
          (2, 38, false),
          (1, 20, false),
          (1, 21, true),
          (4, 500, true),
          (5, 500, false),
          (1, 0, false),
        ];

        for (final (int page, int totalResults, bool hasMore) in cases) {
          test('page $page of $totalResults results → $hasMore', () async {
            final List<Article> articles = buildArticles('h$page', 1);
            stubConnected(connected: true);
            when(() => remoteHeadlines(page: page)).thenAnswer(
              (_) async =>
                  buildRemotePage(articles, totalResults: totalResults),
            );
            when(() => cacheHeadlines(articles, page: page))
                .thenAnswer((_) async {});

            final Result<PaginatedArticles> result = await getHeadlines(
              page: page,
            );

            expect(
              result,
              pageSuccess(
                buildPage(
                  articles,
                  page: page,
                  hasMore: hasMore,
                  isFromCache: false,
                ),
              ),
            );
          });
        }
      });

      test('works out hasMore from totalResults, not the item count', () async {
        stubConnected(connected: true);
        when(remoteHeadlines)
            .thenAnswer((_) async => buildRemotePage(const <Article>[]));
        when(() => cacheHeadlines(const <Article>[])).thenAnswer((_) async {});

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageSuccess(
            buildPage(
              const <Article>[],
              page: 1,
              hasMore: true,
              isFromCache: false,
            ),
          ),
        );
      });

      test('a CacheException while persisting is logged as a warning and '
          'the fetched page is still returned', () async {
        const CacheException persistError = CacheException('disk full');
        final List<Article> articles = buildArticles('w', 2);
        stubConnected(connected: true);
        when(remoteHeadlines)
            .thenAnswer((_) async => buildRemotePage(articles));
        when(() => cacheHeadlines(articles)).thenThrow(persistError);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageSuccess(
            buildPage(articles, page: 1, hasMore: true, isFromCache: false),
          ),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          remoteHeadlines,
          () => cacheHeadlines(articles),
        ]);
        verify(
          () => logger.warning(
            any(),
            error: persistError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      });

      test('any other error while persisting is logged as an error and '
          'the fetched page is still returned', () async {
        final StateError persistError = StateError('unexpected');
        final List<Article> articles = buildArticles('e', 2);
        stubConnected(connected: true);
        when(remoteHeadlines)
            .thenAnswer((_) async => buildRemotePage(articles));
        when(() => cacheHeadlines(articles)).thenThrow(persistError);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageSuccess(
            buildPage(articles, page: 1, hasMore: true, isFromCache: false),
          ),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          remoteHeadlines,
          () => cacheHeadlines(articles),
        ]);
        verify(
          () => logger.error(
            any(),
            error: persistError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      });
    });

    group('remote failure on page 1', () {
      const List<AppException> fallbackErrors = <AppException>[
        NetworkException('timeout'),
        ServerException(message: 'boom', statusCode: 500),
        ParsingException('bad body'),
      ];

      for (final AppException remoteError in fallbackErrors) {
        test('${remoteError.runtimeType} falls back to the cached feed as '
            'page 1, no more pages, from cache', () async {
          final List<Article> cached = buildArticles('c', 2);
          stubConnected(connected: true);
          when(remoteHeadlines).thenThrow(remoteError);
          when(cachedHeadlines).thenAnswer((_) async => cached);

          final Result<PaginatedArticles> result = await getHeadlines();

          expect(
            result,
            pageSuccess(
              buildPage(cached, page: 1, hasMore: false, isFromCache: true),
            ),
          );
          verifyInOrder(<Object? Function()>[
            () => networkInfo.isConnected,
            remoteHeadlines,
            cachedHeadlines,
          ]);
          verify(() => logger.warning(any(), error: remoteError)).called(1);
          verifyNoMoreCalls();
        });
      }

      test(
        'UnauthorizedException is returned without reading the cache',
        () async {
          const UnauthorizedException remoteError = UnauthorizedException(
            message: 'bad key',
            code: 'apiKeyInvalid',
          );
          stubConnected(connected: true);
          when(remoteHeadlines).thenThrow(remoteError);

          final Result<PaginatedArticles> result = await getHeadlines();

          expect(
            result,
            pageFailure(const failures.UnauthorizedFailure('bad key')),
          );
          verifyInOrder(<Object? Function()>[
            () => networkInfo.isConnected,
            remoteHeadlines,
          ]);
          verifyNoMoreCalls();
        },
      );

      test('an empty cache returns the original remote failure', () async {
        stubConnected(connected: true);
        when(remoteHeadlines).thenThrow(const NetworkException('timeout'));
        when(cachedHeadlines).thenAnswer((_) async => <Article>[]);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(result, pageFailure(const failures.NetworkFailure('timeout')));
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          remoteHeadlines,
          cachedHeadlines,
        ]);
        verifyNoMoreCalls();
      });

      test('an empty cache keeps the ServerFailure status code', () async {
        stubConnected(connected: true);
        when(remoteHeadlines)
            .thenThrow(const ServerException(message: 'down', statusCode: 503));
        when(cachedHeadlines).thenAnswer((_) async => <Article>[]);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageFailure(const failures.ServerFailure('down', statusCode: 503)),
        );
      });

      test('a CacheException while reading the cache is logged as a warning '
          'and the original remote failure is returned', () async {
        const CacheException readError = CacheException('corrupt box');
        stubConnected(connected: true);
        when(remoteHeadlines).thenThrow(const NetworkException('timeout'));
        when(cachedHeadlines).thenThrow(readError);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(result, pageFailure(const failures.NetworkFailure('timeout')));
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          remoteHeadlines,
          cachedHeadlines,
        ]);
        verify(
          () => logger.warning(
            any(),
            error: readError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      });

      test('any other error while reading the cache is logged as a warning '
          'and the original remote failure is returned', () async {
        final StateError readError = StateError('unexpected');
        stubConnected(connected: true);
        when(remoteHeadlines).thenThrow(const NetworkException('timeout'));
        when(cachedHeadlines).thenThrow(readError);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(result, pageFailure(const failures.NetworkFailure('timeout')));
        verify(
          () => logger.warning(
            any(),
            error: readError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
      });

      test('forceRefresh still falls back to the cache', () async {
        const NetworkException remoteError = NetworkException('timeout');
        final List<Article> cached = buildArticles('f', 1);
        stubConnected(connected: true);
        when(() => remoteHeadlines(forceRefresh: true)).thenThrow(remoteError);
        when(cachedHeadlines).thenAnswer((_) async => cached);

        final Result<PaginatedArticles> result = await getHeadlines(
          forceRefresh: true,
        );

        expect(
          result,
          pageSuccess(
            buildPage(cached, page: 1, hasMore: false, isFromCache: true),
          ),
        );
        verify(() => logger.warning(any(), error: remoteError)).called(1);
      });
    });

    group('remote failure on a later page', () {
      test('returns the original failure without reading the cache', () async {
        stubConnected(connected: true);
        when(() => remoteHeadlines(page: 2))
            .thenThrow(const NetworkException('timeout'));

        final Result<PaginatedArticles> result = await getHeadlines(page: 2);

        expect(result, pageFailure(const failures.NetworkFailure('timeout')));
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          () => remoteHeadlines(page: 2),
        ]);
        verifyNoMoreCalls();
      });
    });

    group('offline (NetworkInfo reports no connection)', () {
      test('serves the cached feed without asking the network', () async {
        final List<Article> cached = buildArticles('o', 3);
        stubConnected(connected: false);
        when(cachedHeadlines).thenAnswer((_) async => cached);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageSuccess(
            buildPage(cached, page: 1, hasMore: false, isFromCache: true),
          ),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          cachedHeadlines,
        ]);
        verify(
          () => logger.warning(
            any(),
            error: const NetworkException(offlineMessage),
          ),
        ).called(1);
        verifyNoMoreCalls();
      });

      test('an empty cache returns NetworkFailure', () async {
        stubConnected(connected: false);
        when(cachedHeadlines).thenAnswer((_) async => <Article>[]);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageFailure(const failures.NetworkFailure(offlineMessage)),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          cachedHeadlines,
        ]);
        verifyNoMoreCalls();
      });

      test(
        'a later page returns NetworkFailure without reading the cache',
        () async {
          stubConnected(connected: false);

          final Result<PaginatedArticles> result = await getHeadlines(page: 3);

          expect(
            result,
            pageFailure(const failures.NetworkFailure(offlineMessage)),
          );
          verify(() => networkInfo.isConnected).called(1);
          verifyNoMoreCalls();
        },
      );
    });

    group('unexpected errors', () {
      test('a non-AppException from the remote call is logged and returned '
          'as UnexpectedFailure, without a cache fallback', () async {
        final StateError remoteError = StateError('mapper bug');
        stubConnected(connected: true);
        when(remoteHeadlines).thenThrow(remoteError);

        final Result<PaginatedArticles> result = await getHeadlines();

        expect(
          result,
          pageFailure(
            const failures.UnexpectedFailure(
              'Unexpected error while loading top headlines',
            ),
          ),
        );
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          remoteHeadlines,
        ]);
        verify(
          () => logger.error(
            any(),
            error: remoteError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      });

      test(
        'an error from NetworkInfo is returned as UnexpectedFailure',
        () async {
          final StateError connectivityError = StateError('platform');
          when(() => networkInfo.isConnected).thenThrow(connectivityError);

          final Result<PaginatedArticles> result = await getHeadlines();

          expect(
            result,
            pageFailure(
              const failures.UnexpectedFailure(
                'Unexpected error while loading top headlines',
              ),
            ),
          );
          verify(() => networkInfo.isConnected).called(1);
          verify(
            () => logger.error(
              any(),
              error: connectivityError,
              stackTrace: any(named: 'stackTrace', that: isNotNull),
            ),
          ).called(1);
          verifyNoMoreCalls();
        },
      );
    });
  });

  group('searchArticles', () {
    test('forwards query, page and page size 20 and returns the page as not '
        'from cache, without touching local storage', () async {
      final List<Article> articles = buildArticles('s', 3);
      stubConnected(connected: true);
      when(remoteSearch).thenAnswer((_) async => buildRemotePage(articles));

      final Result<PaginatedArticles> result = await search();

      expect(
        result,
        pageSuccess(
          buildPage(articles, page: 1, hasMore: true, isFromCache: false),
        ),
      );
      verifyInOrder(<Object? Function()>[
        () => networkInfo.isConnected,
        remoteSearch,
      ]);
      verifyNoMoreCalls();
    });

    test('stops at the 100-result cap', () async {
      final List<Article> articles = buildArticles('cap', 2);
      stubConnected(connected: true);
      when(
        () => remoteSearch(query: 'dart', page: 5),
      ).thenAnswer((_) async => buildRemotePage(articles, totalResults: 1000));

      final Result<PaginatedArticles> result = await search(
        query: 'dart',
        page: 5,
      );

      expect(
        result,
        pageSuccess(
          buildPage(articles, page: 5, hasMore: false, isFromCache: false),
        ),
      );
    });

    test('offline returns NetworkFailure without asking the network', () async {
      stubConnected(connected: false);

      final Result<PaginatedArticles> result = await search();

      expect(
        result,
        pageFailure(const failures.NetworkFailure(offlineMessage)),
      );
      verify(() => networkInfo.isConnected).called(1);
      verifyNoMoreCalls();
    });

    const List<(AppException, failures.Failure)> mappings =
        <(AppException, failures.Failure)>[
          (NetworkException('timeout'), failures.NetworkFailure('timeout')),
          (
            ServerException(message: 'rate limited', statusCode: 429),
            failures.ServerFailure('rate limited', statusCode: 429),
          ),
          (
            UnauthorizedException(message: 'bad key'),
            failures.UnauthorizedFailure('bad key'),
          ),
          (
            ParsingException('bad body'),
            failures.UnexpectedFailure('bad body'),
          ),
        ];

    for (final (AppException remoteError, failures.Failure failure)
        in mappings) {
      test('${remoteError.runtimeType} → ${failure.runtimeType}, '
          'no cache fallback', () async {
        stubConnected(connected: true);
        when(remoteSearch).thenThrow(remoteError);

        final Result<PaginatedArticles> result = await search();

        expect(result, pageFailure(failure));
        verifyInOrder(<Object? Function()>[
          () => networkInfo.isConnected,
          remoteSearch,
        ]);
        verifyNoMoreCalls();
      });
    }

    test(
      'a non-AppException is logged and returned as UnexpectedFailure',
      () async {
        final StateError remoteError = StateError('mapper bug');
        stubConnected(connected: true);
        when(remoteSearch).thenThrow(remoteError);

        final Result<PaginatedArticles> result = await search();

        expect(
          result,
          pageFailure(
            const failures.UnexpectedFailure(
              'Unexpected error while searching articles',
            ),
          ),
        );
        verify(
          () => logger.error(
            any(),
            error: remoteError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
      },
    );
  });

  group('toggleBookmark', () {
    const String url = 'https://example.com/bookmark';
    late Article article;

    setUp(() {
      article = buildArticle(url);
    });

    test('saves an article that is not bookmarked and returns true', () async {
      when(() => local.isBookmarked(url)).thenAnswer((_) async => false);
      when(() => local.saveBookmark(article)).thenAnswer((_) async {});

      final Result<bool> result = await repository.toggleBookmark(article);

      expect(result, boolSuccess(value: true));
      verifyInOrder(<Object? Function()>[
        () => local.isBookmarked(url),
        () => local.saveBookmark(article),
      ]);
      verifyNoMoreCalls();
    });

    test('removes a bookmarked article and returns false', () async {
      when(() => local.isBookmarked(url)).thenAnswer((_) async => true);
      when(() => local.removeBookmark(url)).thenAnswer((_) async {});

      final Result<bool> result = await repository.toggleBookmark(article);

      expect(result, boolSuccess(value: false));
      verifyInOrder(<Object? Function()>[
        () => local.isBookmarked(url),
        () => local.removeBookmark(url),
      ]);
      verifyNoMoreCalls();
    });

    test('a CacheException while reading returns CacheFailure and writes '
        'nothing', () async {
      when(() => local.isBookmarked(url))
          .thenThrow(const CacheException('read failed'));

      final Result<bool> result = await repository.toggleBookmark(article);

      expect(result, boolFailure(const failures.CacheFailure('read failed')));
      verify(() => local.isBookmarked(url)).called(1);
      verifyNoMoreCalls();
    });

    test('a CacheException while saving returns CacheFailure', () async {
      when(() => local.isBookmarked(url)).thenAnswer((_) async => false);
      when(() => local.saveBookmark(article))
          .thenThrow(const CacheException('write failed'));

      final Result<bool> result = await repository.toggleBookmark(article);

      expect(result, boolFailure(const failures.CacheFailure('write failed')));
      verifyInOrder(<Object? Function()>[
        () => local.isBookmarked(url),
        () => local.saveBookmark(article),
      ]);
      verifyNoMoreCalls();
    });

    test('a CacheException while removing returns CacheFailure', () async {
      when(() => local.isBookmarked(url)).thenAnswer((_) async => true);
      when(() => local.removeBookmark(url))
          .thenThrow(const CacheException('delete failed'));

      final Result<bool> result = await repository.toggleBookmark(article);

      expect(result, boolFailure(const failures.CacheFailure('delete failed')));
      verifyInOrder(<Object? Function()>[
        () => local.isBookmarked(url),
        () => local.removeBookmark(url),
      ]);
      verifyNoMoreCalls();
    });

    test(
      'a non-AppException is logged and returned as UnexpectedFailure',
      () async {
        final StateError storageError = StateError('unexpected');
        when(() => local.isBookmarked(url)).thenThrow(storageError);

        final Result<bool> result = await repository.toggleBookmark(article);

        expect(
          result,
          boolFailure(
            const failures.UnexpectedFailure(
              'Unexpected error while toggling a bookmark',
            ),
          ),
        );
        verify(() => local.isBookmarked(url)).called(1);
        verify(
          () => logger.error(
            any(),
            error: storageError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      },
    );
  });

  group('isBookmarked', () {
    const String url = 'https://example.com/bookmark';

    test('returns true when the article is bookmarked', () async {
      when(() => local.isBookmarked(url)).thenAnswer((_) async => true);

      final Result<bool> result = await repository.isBookmarked(url);

      expect(result, boolSuccess(value: true));
      verify(() => local.isBookmarked(url)).called(1);
      verifyNoMoreCalls();
    });

    test('returns false when the article is not bookmarked', () async {
      when(() => local.isBookmarked(url)).thenAnswer((_) async => false);

      final Result<bool> result = await repository.isBookmarked(url);

      expect(result, boolSuccess(value: false));
      verify(() => local.isBookmarked(url)).called(1);
      verifyNoMoreCalls();
    });

    test('a CacheException returns CacheFailure', () async {
      when(() => local.isBookmarked(url))
          .thenThrow(const CacheException('read failed'));

      final Result<bool> result = await repository.isBookmarked(url);

      expect(result, boolFailure(const failures.CacheFailure('read failed')));
      verify(() => local.isBookmarked(url)).called(1);
      verifyNoMoreCalls();
    });

    test(
      'a non-AppException is logged and returned as UnexpectedFailure',
      () async {
        final StateError storageError = StateError('unexpected');
        when(() => local.isBookmarked(url)).thenThrow(storageError);

        final Result<bool> result = await repository.isBookmarked(url);

        expect(
          result,
          boolFailure(
            const failures.UnexpectedFailure(
              'Unexpected error while checking a bookmark',
            ),
          ),
        );
        verify(() => local.isBookmarked(url)).called(1);
        verify(
          () => logger.error(
            any(),
            error: storageError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      },
    );
  });

  group('getBookmarks', () {
    test('returns the stored bookmarks, from local storage only', () async {
      final List<Article> stored = <Article>[
        buildArticle('https://example.com/newest'),
        buildArticleWithoutOptionals('https://example.com/oldest'),
      ];
      when(() => local.getBookmarks()).thenAnswer((_) async => stored);

      final Result<List<Article>> result = await repository.getBookmarks();

      expect(result, listSuccess(stored));
      // No NetworkInfo, remote or logger call: verifyNoMoreCalls checks all.
      verify(() => local.getBookmarks()).called(1);
      verifyNoMoreCalls();
    });

    test('a CacheException returns CacheFailure without logging', () async {
      when(() => local.getBookmarks())
          .thenThrow(const CacheException('read failed'));

      final Result<List<Article>> result = await repository.getBookmarks();

      expect(result, listFailure(const failures.CacheFailure('read failed')));
      verify(() => local.getBookmarks()).called(1);
      verifyNoMoreCalls();
    });

    test(
      'a non-AppException is logged and returned as UnexpectedFailure',
      () async {
        final StateError storageError = StateError('unexpected');
        when(() => local.getBookmarks()).thenThrow(storageError);

        final Result<List<Article>> result = await repository.getBookmarks();

        expect(
          result,
          listFailure(
            const failures.UnexpectedFailure(
              'Unexpected error while loading bookmarks',
            ),
          ),
        );
        verify(() => local.getBookmarks()).called(1);
        verify(
          () => logger.error(
            'Unexpected error while loading bookmarks',
            error: storageError,
            stackTrace: any(named: 'stackTrace', that: isNotNull),
          ),
        ).called(1);
        verifyNoMoreCalls();
      },
    );
  });
}
