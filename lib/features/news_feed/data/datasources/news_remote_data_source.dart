import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

/// Remote source of news articles (NewsAPI.org).
///
/// Speaks entities: the implementation (`NewsRemoteDataSourceImpl`, Step 19)
/// maps the API DTOs to [RemoteArticlesPage], dropping invalid and moderated
/// articles, so callers never see a model.
///
/// Every method throws an `AppException` subtype on failure (the
/// implementation wraps each API call in `guardApiCall`, D10):
/// - `NetworkException`: no connection, timeout, cancelled, bad certificate.
/// - `UnauthorizedException`: HTTP 401 (missing or invalid API key).
/// - `ServerException`: any other non-2xx response (including 429), or an
///   unknown transport error.
/// - `ParsingException`: the response body could not be decoded or mapped.
///
/// Preconditions for all methods: `page >= 1` (1-based) and `pageSize >= 1`.
/// The page size is chosen by the caller (the repository passes
/// `AppConstants.newsPageSize`, Step 20).
abstract interface class NewsRemoteDataSource {
  /// Fetches one page of top headlines for [category].
  ///
  /// The implementation maps [category] to the API's category string with an
  /// exhaustive `switch` (D12), never with `.name`.
  ///
  /// When [forceRefresh] is `true` the HTTP cache is bypassed and the fresh
  /// response replaces the cached one; when `false` a cached response younger
  /// than the cache's max-stale window may be returned.
  Future<RemoteArticlesPage> getTopHeadlines({
    required NewsCategory category,
    required int page,
    required int pageSize,
    required bool forceRefresh,
  });

  /// Searches all articles for [query].
  ///
  /// [query] must already be trimmed and non-blank (the `SearchArticles` use
  /// case guarantees it). Search results are never persisted locally.
  Future<RemoteArticlesPage> searchArticles({
    required String query,
    required int page,
    required int pageSize,
  });
}
