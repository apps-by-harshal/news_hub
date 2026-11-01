import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_state.dart';

/// Drives the top-headlines feed: first load, category chips,
/// pull-to-refresh and infinite scroll (Step 21).
///
/// Event handling:
/// - [NewsFeedStarted] (`droppable`): loads page 1 of `general`, only from
///   [NewsFeedInitial].
/// - [NewsFeedCategoryChanged] (`restartable`): loads page 1 of the chosen
///   category; ignored when that category is already loading or shown.
/// - [NewsFeedRefreshed] (`restartable`): with a list shown, keeps it
///   (`isRefreshing`) and replaces it with a fresh page 1, or keeps it with
///   `refreshFailure`; after [NewsFeedFailure] it retries like a first load.
///   Always `forceRefresh: true`.
/// - [NewsFeedNextPageRequested] (`droppable`): appends the next page, only
///   when a list is shown with more pages, online, and nothing else in
///   progress; a failure keeps the list with `loadMoreFailure`.
///
/// Transformers only order events of one type, so results that arrive
/// after a newer page-1 load started (another category, a refresh) are
/// dropped with a request id: every page-1 load increments it, and each
/// handler checks it after its `await`.
///
/// Articles are de-duplicated by URL (D11), keeping the copy already shown,
/// so list keys stay unique even when NewsAPI pages overlap.
///
/// `isOffline` comes from `PaginatedArticles.isFromCache` (D12), never from
/// `NetworkInfo`.
interface class NewsFeedBloc extends Bloc<NewsFeedEvent, NewsFeedState> {
  /// Creates the bloc in [NewsFeedInitial]. Callers pass `getTopHeadlines:`.
  NewsFeedBloc({required this._getTopHeadlines})
    : super(const NewsFeedInitial()) {
    on<NewsFeedStarted>(_onStarted, transformer: droppable<NewsFeedStarted>());
    on<NewsFeedCategoryChanged>(
      _onCategoryChanged,
      transformer: restartable<NewsFeedCategoryChanged>(),
    );
    on<NewsFeedRefreshed>(
      _onRefreshed,
      transformer: restartable<NewsFeedRefreshed>(),
    );
    on<NewsFeedNextPageRequested>(
      _onNextPageRequested,
      transformer: droppable<NewsFeedNextPageRequested>(),
    );
  }

  final GetTopHeadlines _getTopHeadlines;

  /// Id of the latest page-1 load. A result whose id no longer matches is
  /// stale and is not emitted.
  int _requestId = 0;

  Future<void> _onStarted(
    NewsFeedStarted event,
    Emitter<NewsFeedState> emit,
  ) async {
    if (state is! NewsFeedInitial) return;
    await _loadFirstPage(state.category, forceRefresh: false, emit: emit);
  }

  Future<void> _onCategoryChanged(
    NewsFeedCategoryChanged event,
    Emitter<NewsFeedState> emit,
  ) async {
    final NewsFeedState current = state;
    final bool alreadyShown =
        event.category == current.category &&
        (current is NewsFeedLoading || current is NewsFeedLoaded);
    if (alreadyShown) return;
    await _loadFirstPage(event.category, forceRefresh: false, emit: emit);
  }

  Future<void> _onRefreshed(
    NewsFeedRefreshed event,
    Emitter<NewsFeedState> emit,
  ) async {
    switch (state) {
      case final NewsFeedLoaded current:
        await _refresh(current, emit);
      case NewsFeedFailure(:final NewsCategory category):
        await _loadFirstPage(category, forceRefresh: true, emit: emit);
      case NewsFeedInitial() || NewsFeedLoading():
        return;
    }
  }

  Future<void> _onNextPageRequested(
    NewsFeedNextPageRequested event,
    Emitter<NewsFeedState> emit,
  ) async {
    final NewsFeedState current = state;
    if (current is! NewsFeedLoaded ||
        !current.hasMore ||
        current.isOffline ||
        current.isLoadingMore ||
        current.isRefreshing) {
      return;
    }

    final int requestId = _requestId;
    final NewsFeedLoaded loadingMore = current.copyWith(
      isLoadingMore: true,
      loadMoreFailure: () => null,
      refreshFailure: () => null,
    );
    emit(loadingMore);

    final Result<PaginatedArticles> result = await _getTopHeadlines(
      GetTopHeadlinesParams(
        category: current.category,
        page: current.page + 1,
        forceRefresh: false,
      ),
    );
    if (requestId != _requestId) return;

    emit(switch (result) {
      Success<PaginatedArticles>(:final PaginatedArticles value) =>
        loadingMore.copyWith(
          articles: _appendNew(loadingMore.articles, value.items),
          page: value.page,
          hasMore: value.hasMore,
          isOffline: value.isFromCache,
          isLoadingMore: false,
        ),
      Failure<PaginatedArticles>(:final failures.Failure failure) =>
        loadingMore.copyWith(
          isLoadingMore: false,
          loadMoreFailure: () => failure,
        ),
    });
  }

  /// Shows [NewsFeedLoading], then page 1 of [category] or
  /// [NewsFeedFailure].
  Future<void> _loadFirstPage(
    NewsCategory category, {
    required bool forceRefresh,
    required Emitter<NewsFeedState> emit,
  }) async {
    final int requestId = ++_requestId;
    emit(NewsFeedLoading(category: category));

    final Result<PaginatedArticles> result = await _getTopHeadlines(
      GetTopHeadlinesParams(
        category: category,
        page: 1,
        forceRefresh: forceRefresh,
      ),
    );
    if (requestId != _requestId) return;

    emit(switch (result) {
      Success<PaginatedArticles>(:final PaginatedArticles value) => _firstPage(
        category,
        value,
      ),
      Failure<PaginatedArticles>(:final failures.Failure failure) =>
        NewsFeedFailure(category: category, failure: failure),
    });
  }

  /// Keeps [current] on screen while a fresh page 1 loads; on failure the
  /// list stays with `refreshFailure`.
  Future<void> _refresh(
    NewsFeedLoaded current,
    Emitter<NewsFeedState> emit,
  ) async {
    final int requestId = ++_requestId;
    final NewsFeedLoaded refreshing = current.copyWith(
      isRefreshing: true,
      isLoadingMore: false,
      loadMoreFailure: () => null,
      refreshFailure: () => null,
    );
    emit(refreshing);

    final Result<PaginatedArticles> result = await _getTopHeadlines(
      GetTopHeadlinesParams(
        category: current.category,
        page: 1,
        forceRefresh: true,
      ),
    );
    if (requestId != _requestId) return;

    emit(switch (result) {
      Success<PaginatedArticles>(:final PaginatedArticles value) => _firstPage(
        current.category,
        value,
      ),
      Failure<PaginatedArticles>(:final failures.Failure failure) =>
        refreshing.copyWith(isRefreshing: false, refreshFailure: () => failure),
    });
  }
}

/// A fresh list from page 1: no transient flags, no failures.
NewsFeedLoaded _firstPage(NewsCategory category, PaginatedArticles page) {
  return NewsFeedLoaded(
    category: category,
    articles: _appendNew(const <Article>[], page.items),
    page: page.page,
    hasMore: page.hasMore,
    isOffline: page.isFromCache,
  );
}

/// [shown] followed by the articles of [incoming] whose URL is not already
/// present. The first copy of a URL wins, also within [incoming].
List<Article> _appendNew(List<Article> shown, List<Article> incoming) {
  final Set<String> urls = <String>{
    for (final Article article in shown) article.url,
  };
  return <Article>[
    ...shown,
    for (final Article article in incoming)
      if (urls.add(article.url)) article,
  ];
}
