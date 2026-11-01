import 'dart:math' as math;

import 'package:news_hub/core/config/app_constants.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';

/// Message of the `NetworkFailure` returned when [NetworkInfo] reports no
/// connection and nothing cached can be served instead.
const String _offlineMessage = 'No network connection';

/// [NewsRepository] backed by NewsAPI (remote) and Hive (local), D12.
///
/// - **Top headlines:** network-first with a cache fallback on page 1.
///   [NetworkInfo] is only a fast-path hint: when it reports no connection
///   the network is not asked, and a failed request still falls back.
///   `UnauthorizedException` never falls back (a bad API key must not look
///   like being offline).
/// - **Search:** network only, never persisted.
/// - **Bookmarks:** local only. Toggling is read-then-write; the list comes
///   back newest first, as stored (Step 24).
///
/// Every method returns a [Result] and never throws. An [AppException]
/// becomes `Failure(e.toFailure())` without logging (D9); anything else is
/// logged as an error and becomes `failures.UnexpectedFailure`.
final class NewsRepositoryImpl implements NewsRepository {
  const NewsRepositoryImpl({
    required this._remoteDataSource,
    required this._localDataSource,
    required this._networkInfo,
    required this._logger,
  });

  final NewsRemoteDataSource _remoteDataSource;
  final NewsLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final AppLogger _logger;

  @override
  Future<Result<PaginatedArticles>> getTopHeadlines({
    required NewsCategory category,
    required int page,
    required bool forceRefresh,
  }) {
    return _guard<PaginatedArticles>('loading top headlines', () async {
      if (!await _networkInfo.isConnected) {
        return _cachedHeadlinesOr(
          category: category,
          page: page,
          remoteError: const NetworkException(_offlineMessage),
        );
      }

      final RemoteArticlesPage remotePage;
      try {
        remotePage = await _remoteDataSource.getTopHeadlines(
          category: category,
          page: page,
          pageSize: AppConstants.newsPageSize,
          forceRefresh: forceRefresh,
        );
      } on UnauthorizedException {
        rethrow;
      } on AppException catch (error) {
        return _cachedHeadlinesOr(
          category: category,
          page: page,
          remoteError: error,
        );
      }

      await _persist(
        category: category,
        page: page,
        articles: remotePage.articles,
      );
      return Success<PaginatedArticles>(_freshPage(remotePage, page));
    });
  }

  @override
  Future<Result<PaginatedArticles>> searchArticles({
    required String query,
    required int page,
  }) {
    return _guard<PaginatedArticles>('searching articles', () async {
      if (!await _networkInfo.isConnected) {
        return const Failure<PaginatedArticles>(
          failures.NetworkFailure(_offlineMessage),
        );
      }

      final RemoteArticlesPage remotePage = await _remoteDataSource
          .searchArticles(
            query: query,
            page: page,
            pageSize: AppConstants.newsPageSize,
          );
      return Success<PaginatedArticles>(_freshPage(remotePage, page));
    });
  }

  @override
  Future<Result<bool>> toggleBookmark(Article article) {
    return _guard<bool>('toggling a bookmark', () async {
      if (await _localDataSource.isBookmarked(article.url)) {
        await _localDataSource.removeBookmark(article.url);
        return const Success<bool>(false);
      }
      await _localDataSource.saveBookmark(article);
      return const Success<bool>(true);
    });
  }

  @override
  Future<Result<bool>> isBookmarked(String url) {
    return _guard<bool>('checking a bookmark', () async {
      return Success<bool>(await _localDataSource.isBookmarked(url));
    });
  }

  @override
  Future<Result<List<Article>>> getBookmarks() {
    return _guard<List<Article>>('loading bookmarks', () async {
      return Success<List<Article>>(await _localDataSource.getBookmarks());
    });
  }

  /// Runs [body], turning an [AppException] into its domain failure (D9)
  /// and anything else into a logged `failures.UnexpectedFailure` whose
  /// message names [operation].
  Future<Result<T>> _guard<T>(
    String operation,
    Future<Result<T>> Function() body,
  ) async {
    try {
      return await body();
    } on AppException catch (error) {
      return Failure<T>(error.toFailure());
    } on Object catch (error, stackTrace) {
      final String message = 'Unexpected error while $operation';
      _logger.error(message, error: error, stackTrace: stackTrace);
      return Failure<T>(failures.UnexpectedFailure(message));
    }
  }

  /// The cache fallback after [remoteError] (D9, D12).
  ///
  /// Returns the cached feed for [category] as `page: 1, hasMore: false,
  /// isFromCache: true`. Returns the failure for [remoteError] instead when
  /// [page] is after the first (the cached feed is always page 1), when the
  /// cache is empty, or when reading it fails (logged as a warning).
  Future<Result<PaginatedArticles>> _cachedHeadlinesOr({
    required NewsCategory category,
    required int page,
    required AppException remoteError,
  }) async {
    final Result<PaginatedArticles> remoteFailure = Failure<PaginatedArticles>(
      remoteError.toFailure(),
    );
    if (page > 1) {
      return remoteFailure;
    }

    final List<Article> cached;
    try {
      cached = await _localDataSource.getCachedTopHeadlines(category);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Could not read the cached top headlines for ${category.name}',
        error: error,
        stackTrace: stackTrace,
      );
      return remoteFailure;
    }
    if (cached.isEmpty) {
      return remoteFailure;
    }

    _logger.warning(
      'Serving cached top headlines for ${category.name} after a remote '
      'failure',
      error: remoteError,
    );
    return Success<PaginatedArticles>(
      PaginatedArticles(
        items: cached,
        page: 1,
        hasMore: false,
        isFromCache: true,
      ),
    );
  }

  /// Persists a freshly fetched page. A failure never fails the call (D12):
  /// a `CacheException` is logged as a warning, anything else as an error.
  Future<void> _persist({
    required NewsCategory category,
    required int page,
    required List<Article> articles,
  }) async {
    try {
      await _localDataSource.cacheTopHeadlines(
        category: category,
        page: page,
        articles: articles,
      );
    } on CacheException catch (error, stackTrace) {
      _logger.warning(
        'Could not cache top headlines for ${category.name}, page $page',
        error: error,
        stackTrace: stackTrace,
      );
    } on Object catch (error, stackTrace) {
      _logger.error(
        'Unexpected error while caching top headlines for ${category.name}, '
        'page $page',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// A page fetched from the network: never from the cache.
PaginatedArticles _freshPage(RemoteArticlesPage remotePage, int page) {
  return PaginatedArticles(
    items: remotePage.articles,
    page: page,
    hasMore: _hasMore(page: page, totalResults: remotePage.totalResults),
    isFromCache: false,
  );
}

/// Whether another page can be requested (D11): based on the API's
/// `totalResults`, capped at [AppConstants.newsMaxResults], never on how
/// many articles survived mapping.
bool _hasMore({required int page, required int totalResults}) {
  return page * AppConstants.newsPageSize <
      math.min(totalResults, AppConstants.newsMaxResults);
}
