import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_state.dart';

import '../../../../../fixtures/article_builders.dart';
import '../../../../../helpers/mocks.dart';

// The use cases are `final` classes, so they can't be mocked outside their
// library: the bloc gets a real `GetTopHeadlines` on a mocked repository.
// Stubs use exact argument values; every test ends with
// `verifyNoMoreInteractions`.

const String u1 = 'https://example.com/1';
const String u2 = 'https://example.com/2';
const String u3 = 'https://example.com/3';
const String u4 = 'https://example.com/4';
const String u5 = 'https://example.com/5';

const failures.Failure networkFailure = failures.NetworkFailure('offline');
const failures.Failure serverFailure = failures.ServerFailure(
  'boom',
  statusCode: 500,
);

List<Article> articlesOf(List<String> urls) => urls.map(buildArticle).toList();

PaginatedArticles buildPage({
  required List<Article> items,
  required int page,
  required bool hasMore,
  bool isFromCache = false,
}) => PaginatedArticles(
  items: items,
  page: page,
  hasMore: hasMore,
  isFromCache: isFromCache,
);

/// Page 1 of a feed: [u1], [u2], more to come.
PaginatedArticles page1() =>
    buildPage(items: articlesOf(<String>[u1, u2]), page: 1, hasMore: true);

/// Page 2 of a feed: [u3], [u4], the last page.
PaginatedArticles page2() =>
    buildPage(items: articlesOf(<String>[u3, u4]), page: 2, hasMore: false);

/// The repository's cache fallback: always page 1 with `hasMore: false`.
PaginatedArticles cachedPage() => buildPage(
  items: articlesOf(<String>[u1, u2]),
  page: 1,
  hasMore: false,
  isFromCache: true,
);

Result<PaginatedArticles> successOf(PaginatedArticles page) =>
    Success<PaginatedArticles>(page);

Result<PaginatedArticles> failureOf(failures.Failure failure) =>
    Failure<PaginatedArticles>(failure);

NewsFeedLoaded loaded({
  NewsCategory category = NewsCategory.general,
  required List<Article> articles,
  int page = 1,
  bool hasMore = true,
  bool isOffline = false,
  bool isLoadingMore = false,
  bool isRefreshing = false,
  failures.Failure? loadMoreFailure,
  failures.Failure? refreshFailure,
}) => NewsFeedLoaded(
  category: category,
  articles: articles,
  page: page,
  hasMore: hasMore,
  isOffline: isOffline,
  isLoadingMore: isLoadingMore,
  isRefreshing: isRefreshing,
  loadMoreFailure: loadMoreFailure,
  refreshFailure: refreshFailure,
);

/// Lets pending microtasks run: delivered events, handlers up to their
/// `await`, and emits after a completed future.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MockNewsRepository repository;

  setUp(() {
    repository = MockNewsRepository();
  });

  NewsFeedBloc buildBloc() =>
      NewsFeedBloc(getTopHeadlines: GetTopHeadlines(repository: repository));

  When<Future<Result<PaginatedArticles>>> whenHeadlines(
    NewsCategory category,
    int page, {
    required bool forceRefresh,
  }) => when(
    () => repository.getTopHeadlines(
      category: category,
      page: page,
      forceRefresh: forceRefresh,
    ),
  );

  void verifyHeadlines(
    NewsCategory category,
    int page, {
    required bool forceRefresh,
  }) {
    verify(
      () => repository.getTopHeadlines(
        category: category,
        page: page,
        forceRefresh: forceRefresh,
      ),
    ).called(1);
  }

  test('starts as NewsFeedInitial with the general category', () async {
    final NewsFeedBloc bloc = buildBloc();

    expect(bloc.state, const NewsFeedInitial());

    await bloc.close();
    verifyNoMoreInteractions(repository);
  });

  group('NewsFeedStarted', () {
    blocTest<NewsFeedBloc, NewsFeedState>(
      'loads page 1 of general without forcing a refresh',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page1())),
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedStarted()),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        loaded(articles: articlesOf(<String>[u1, u2])),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'shows a cached page as offline with no more pages',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(cachedPage())),
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedStarted()),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        loaded(
          articles: articlesOf(<String>[u1, u2]),
          hasMore: false,
          isOffline: true,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'shows an empty page as an empty list',
      setUp: () => whenHeadlines(NewsCategory.general, 1, forceRefresh: false)
          .thenAnswer(
            (_) async => successOf(
              buildPage(items: <Article>[], page: 1, hasMore: false),
            ),
          ),
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedStarted()),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        loaded(articles: <Article>[], hasMore: false),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'keeps the first copy of a URL that repeats within page 1',
      setUp: () => whenHeadlines(NewsCategory.general, 1, forceRefresh: false)
          .thenAnswer(
            (_) async => successOf(
              buildPage(
                items: <Article>[
                  buildArticle(u1),
                  buildArticle(u2),
                  buildArticleWithoutOptionals(u1),
                ],
                page: 1,
                hasMore: true,
              ),
            ),
          ),
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedStarted()),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        loaded(articles: <Article>[buildArticle(u1), buildArticle(u2)]),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'emits NewsFeedFailure when page 1 fails',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => failureOf(networkFailure)),
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedStarted()),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        const NewsFeedFailure(
          category: NewsCategory.general,
          failure: networkFailure,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored once the feed has left its initial state',
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedStarted()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a second Started after the first load fetches nothing',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page1())),
      build: buildBloc,
      act: (NewsFeedBloc bloc) async {
        bloc.add(const NewsFeedStarted());
        await flush();
        bloc.add(const NewsFeedStarted());
      },
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        loaded(articles: articlesOf(<String>[u1, u2])),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('NewsFeedCategoryChanged', () {
    blocTest<NewsFeedBloc, NewsFeedState>(
      'loads page 1 of the new category from a shown list',
      setUp: () => whenHeadlines(
        NewsCategory.sports,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page1())),
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u3, u4])),
      act: (NewsFeedBloc bloc) =>
          bloc.add(const NewsFeedCategoryChanged(NewsCategory.sports)),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.sports),
        loaded(
          category: NewsCategory.sports,
          articles: articlesOf(<String>[u1, u2]),
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.sports, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'loads the chosen category from the initial state',
      setUp: () => whenHeadlines(
        NewsCategory.business,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page1())),
      build: buildBloc,
      act: (NewsFeedBloc bloc) =>
          bloc.add(const NewsFeedCategoryChanged(NewsCategory.business)),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.business),
        loaded(
          category: NewsCategory.business,
          articles: articlesOf(<String>[u1, u2]),
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.business, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'emits NewsFeedFailure for the new category when it fails',
      setUp: () => whenHeadlines(
        NewsCategory.sports,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => failureOf(serverFailure)),
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) =>
          bloc.add(const NewsFeedCategoryChanged(NewsCategory.sports)),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.sports),
        const NewsFeedFailure(
          category: NewsCategory.sports,
          failure: serverFailure,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.sports, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'the same category is ignored while its list is shown',
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) =>
          bloc.add(const NewsFeedCategoryChanged(NewsCategory.general)),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'the same category is ignored while it is loading',
      build: buildBloc,
      seed: () => const NewsFeedLoading(category: NewsCategory.general),
      act: (NewsFeedBloc bloc) =>
          bloc.add(const NewsFeedCategoryChanged(NewsCategory.general)),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'the same category after a failure loads it again',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page1())),
      build: buildBloc,
      seed: () => const NewsFeedFailure(
        category: NewsCategory.general,
        failure: networkFailure,
      ),
      act: (NewsFeedBloc bloc) =>
          bloc.add(const NewsFeedCategoryChanged(NewsCategory.general)),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.general),
        loaded(articles: articlesOf(<String>[u1, u2])),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    final Completer<Result<PaginatedArticles>> sports =
        Completer<Result<PaginatedArticles>>();
    final Completer<Result<PaginatedArticles>> science =
        Completer<Result<PaginatedArticles>>();

    blocTest<NewsFeedBloc, NewsFeedState>(
      'only the latest category is shown when an earlier one answers last',
      setUp: () {
        whenHeadlines(
          NewsCategory.sports,
          1,
          forceRefresh: false,
        ).thenAnswer((_) => sports.future);
        whenHeadlines(
          NewsCategory.science,
          1,
          forceRefresh: false,
        ).thenAnswer((_) => science.future);
      },
      build: buildBloc,
      act: (NewsFeedBloc bloc) async {
        bloc.add(const NewsFeedCategoryChanged(NewsCategory.sports));
        await flush();
        bloc.add(const NewsFeedCategoryChanged(NewsCategory.science));
        await flush();
        science.complete(
          successOf(
            buildPage(
              items: articlesOf(<String>[u3, u4]),
              page: 1,
              hasMore: true,
            ),
          ),
        );
        await flush();
        sports.complete(successOf(page1()));
        await flush();
      },
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.sports),
        const NewsFeedLoading(category: NewsCategory.science),
        loaded(
          category: NewsCategory.science,
          articles: articlesOf(<String>[u3, u4]),
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.sports, 1, forceRefresh: false);
        verifyHeadlines(NewsCategory.science, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('NewsFeedRefreshed', () {
    blocTest<NewsFeedBloc, NewsFeedState>(
      'keeps the list while refreshing, then replaces it with fresh page 1',
      setUp: () =>
          whenHeadlines(NewsCategory.general, 1, forceRefresh: true).thenAnswer(
            (_) async => successOf(
              buildPage(
                items: articlesOf(<String>[u5, u1]),
                page: 1,
                hasMore: true,
              ),
            ),
          ),
      build: buildBloc,
      seed: () => loaded(
        articles: articlesOf(<String>[u1, u2, u3, u4]),
        page: 2,
        hasMore: false,
      ),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[
        loaded(
          articles: articlesOf(<String>[u1, u2, u3, u4]),
          page: 2,
          hasMore: false,
          isRefreshing: true,
        ),
        loaded(articles: articlesOf(<String>[u5, u1])),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: true);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a cached answer replaces the list and shows it as offline',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: true,
      ).thenAnswer((_) async => successOf(cachedPage())),
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u3, u4])),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u3, u4]), isRefreshing: true),
        loaded(
          articles: articlesOf(<String>[u1, u2]),
          hasMore: false,
          isOffline: true,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: true);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a failure keeps the list and sets refreshFailure',
      setUp: () => whenHeadlines(
        NewsCategory.health,
        1,
        forceRefresh: true,
      ).thenAnswer((_) async => failureOf(networkFailure)),
      build: buildBloc,
      seed: () => loaded(
        category: NewsCategory.health,
        articles: articlesOf(<String>[u1, u2]),
      ),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[
        loaded(
          category: NewsCategory.health,
          articles: articlesOf(<String>[u1, u2]),
          isRefreshing: true,
        ),
        loaded(
          category: NewsCategory.health,
          articles: articlesOf(<String>[u1, u2]),
          refreshFailure: networkFailure,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.health, 1, forceRefresh: true);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'clears both failures when it starts, so the same failure again is a '
      'new state',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        1,
        forceRefresh: true,
      ).thenAnswer((_) async => failureOf(networkFailure)),
      build: buildBloc,
      seed: () => loaded(
        articles: articlesOf(<String>[u1, u2]),
        loadMoreFailure: serverFailure,
        refreshFailure: networkFailure,
      ),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isRefreshing: true),
        loaded(
          articles: articlesOf(<String>[u1, u2]),
          refreshFailure: networkFailure,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: true);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'after a failed first load it retries with a fresh page 1',
      setUp: () => whenHeadlines(
        NewsCategory.sports,
        1,
        forceRefresh: true,
      ).thenAnswer((_) async => successOf(page1())),
      build: buildBloc,
      seed: () => const NewsFeedFailure(
        category: NewsCategory.sports,
        failure: networkFailure,
      ),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[
        const NewsFeedLoading(category: NewsCategory.sports),
        loaded(
          category: NewsCategory.sports,
          articles: articlesOf(<String>[u1, u2]),
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.sports, 1, forceRefresh: true);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored in the initial state',
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored while page 1 is loading',
      build: buildBloc,
      seed: () => const NewsFeedLoading(category: NewsCategory.general),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedRefreshed()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    final Completer<Result<PaginatedArticles>> nextPage =
        Completer<Result<PaginatedArticles>>();
    final Completer<Result<PaginatedArticles>> refresh =
        Completer<Result<PaginatedArticles>>();

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a page still loading when the refresh starts is dropped',
      setUp: () {
        whenHeadlines(
          NewsCategory.general,
          2,
          forceRefresh: false,
        ).thenAnswer((_) => nextPage.future);
        whenHeadlines(
          NewsCategory.general,
          1,
          forceRefresh: true,
        ).thenAnswer((_) => refresh.future);
      },
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) async {
        bloc.add(const NewsFeedNextPageRequested());
        await flush();
        bloc.add(const NewsFeedRefreshed());
        await flush();
        refresh.complete(
          successOf(
            buildPage(items: articlesOf(<String>[u5]), page: 1, hasMore: true),
          ),
        );
        await flush();
        nextPage.complete(successOf(page2()));
        await flush();
      },
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
        loaded(articles: articlesOf(<String>[u1, u2]), isRefreshing: true),
        loaded(articles: articlesOf(<String>[u5])),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 2, forceRefresh: false);
        verifyHeadlines(NewsCategory.general, 1, forceRefresh: true);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('NewsFeedNextPageRequested', () {
    blocTest<NewsFeedBloc, NewsFeedState>(
      'appends the next page of the current category',
      setUp: () => whenHeadlines(
        NewsCategory.technology,
        2,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page2())),
      build: buildBloc,
      seed: () => loaded(
        category: NewsCategory.technology,
        articles: articlesOf(<String>[u1, u2]),
      ),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[
        loaded(
          category: NewsCategory.technology,
          articles: articlesOf(<String>[u1, u2]),
          isLoadingMore: true,
        ),
        loaded(
          category: NewsCategory.technology,
          articles: articlesOf(<String>[u1, u2, u3, u4]),
          page: 2,
          hasMore: false,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.technology, 2, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'drops URLs that are already in the list and keeps the shown copy',
      setUp: () => whenHeadlines(NewsCategory.general, 2, forceRefresh: false)
          .thenAnswer(
            (_) async => successOf(
              buildPage(
                items: <Article>[
                  buildArticleWithoutOptionals(u2),
                  buildArticle(u3),
                ],
                page: 2,
                hasMore: true,
              ),
            ),
          ),
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
        loaded(articles: articlesOf(<String>[u1, u2, u3]), page: 2),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 2, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a failure keeps the list and sets loadMoreFailure',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        2,
        forceRefresh: false,
      ).thenAnswer((_) async => failureOf(serverFailure)),
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
        loaded(
          articles: articlesOf(<String>[u1, u2]),
          loadMoreFailure: serverFailure,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 2, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a retry after a failure clears both failures when it starts',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        2,
        forceRefresh: false,
      ).thenAnswer((_) async => successOf(page2())),
      build: buildBloc,
      seed: () => loaded(
        articles: articlesOf(<String>[u1, u2]),
        loadMoreFailure: serverFailure,
        refreshFailure: networkFailure,
      ),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
        loaded(
          articles: articlesOf(<String>[u1, u2, u3, u4]),
          page: 2,
          hasMore: false,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 2, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored when there are no more pages',
      build: buildBloc,
      seed: () =>
          loaded(articles: articlesOf(<String>[u1, u2]), hasMore: false),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored while the list is offline',
      build: buildBloc,
      seed: () =>
          loaded(articles: articlesOf(<String>[u1, u2]), isOffline: true),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored while a page is already loading',
      build: buildBloc,
      seed: () =>
          loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored while refreshing',
      build: buildBloc,
      seed: () =>
          loaded(articles: articlesOf(<String>[u1, u2]), isRefreshing: true),
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<NewsFeedBloc, NewsFeedState>(
      'is ignored when no list is shown',
      build: buildBloc,
      act: (NewsFeedBloc bloc) => bloc.add(const NewsFeedNextPageRequested()),
      expect: () => <NewsFeedState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    final Completer<Result<PaginatedArticles>> twice =
        Completer<Result<PaginatedArticles>>();

    blocTest<NewsFeedBloc, NewsFeedState>(
      'two quick requests fetch the next page once',
      setUp: () => whenHeadlines(
        NewsCategory.general,
        2,
        forceRefresh: false,
      ).thenAnswer((_) => twice.future),
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) async {
        bloc
          ..add(const NewsFeedNextPageRequested())
          ..add(const NewsFeedNextPageRequested());
        await flush();
        twice.complete(successOf(page2()));
        await flush();
      },
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
        loaded(
          articles: articlesOf(<String>[u1, u2, u3, u4]),
          page: 2,
          hasMore: false,
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 2, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );

    final Completer<Result<PaginatedArticles>> stalePage =
        Completer<Result<PaginatedArticles>>();
    final Completer<Result<PaginatedArticles>> newCategory =
        Completer<Result<PaginatedArticles>>();

    blocTest<NewsFeedBloc, NewsFeedState>(
      'a page of the previous category is dropped after a category change',
      setUp: () {
        whenHeadlines(
          NewsCategory.general,
          2,
          forceRefresh: false,
        ).thenAnswer((_) => stalePage.future);
        whenHeadlines(
          NewsCategory.sports,
          1,
          forceRefresh: false,
        ).thenAnswer((_) => newCategory.future);
      },
      build: buildBloc,
      seed: () => loaded(articles: articlesOf(<String>[u1, u2])),
      act: (NewsFeedBloc bloc) async {
        bloc.add(const NewsFeedNextPageRequested());
        await flush();
        bloc.add(const NewsFeedCategoryChanged(NewsCategory.sports));
        await flush();
        stalePage.complete(successOf(page2()));
        await flush();
        newCategory.complete(successOf(page1()));
        await flush();
      },
      expect: () => <NewsFeedState>[
        loaded(articles: articlesOf(<String>[u1, u2]), isLoadingMore: true),
        const NewsFeedLoading(category: NewsCategory.sports),
        loaded(
          category: NewsCategory.sports,
          articles: articlesOf(<String>[u1, u2]),
        ),
      ],
      verify: (_) {
        verifyHeadlines(NewsCategory.general, 2, forceRefresh: false);
        verifyHeadlines(NewsCategory.sports, 1, forceRefresh: false);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  test('closing while a request is pending emits nothing more', () async {
    final Completer<Result<PaginatedArticles>> pending =
        Completer<Result<PaginatedArticles>>();
    whenHeadlines(
      NewsCategory.general,
      1,
      forceRefresh: false,
    ).thenAnswer((_) => pending.future);
    final NewsFeedBloc bloc = buildBloc();

    bloc.add(const NewsFeedStarted());
    await flush();
    await bloc.close();
    pending.complete(successOf(page1()));
    await flush();

    expect(bloc.state, const NewsFeedLoading(category: NewsCategory.general));
    verifyHeadlines(NewsCategory.general, 1, forceRefresh: false);
    verifyNoMoreInteractions(repository);
  });
}
