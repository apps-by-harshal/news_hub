import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';

/// Domain contract for reading news and managing bookmarks.
///
/// Implemented by `NewsRepositoryImpl` (Step 20). Every method returns a
/// [Result] and never throws: data-layer exceptions arrive as a [Failure]
/// carrying a domain failure (D9). Domain failures are named here with the
/// `failures.` prefix used by callers (D8).
abstract interface class NewsRepository {
  /// Fetches one page of top headlines for [category].
  ///
  /// [page] is 1-based and must be at least 1. Set [forceRefresh] to `true`
  /// for pull-to-refresh: the request then skips any cached HTTP response
  /// and asks the network for fresh data.
  ///
  /// Network-first with cache fallback:
  /// - On success, returns the page with `isFromCache: false` and persists
  ///   the articles for offline reading. A failure to persist is logged and
  ///   does not fail the call.
  /// - If the device reports no connection, the network is not asked; the
  ///   call goes straight to the cache fallback below with a
  ///   `failures.NetworkFailure`.
  /// - If the network request fails (other than with
  ///   `failures.UnauthorizedFailure`), [page] is 1 and articles for
  ///   [category] are cached, returns them with `isFromCache: true`,
  ///   `page: 1` and `hasMore: false`.
  /// - Otherwise returns the original remote failure:
  ///   `failures.NetworkFailure`, `failures.ServerFailure`,
  ///   `failures.UnauthorizedFailure` or `failures.UnexpectedFailure`.
  ///   `failures.UnauthorizedFailure` never falls back to the cache (a bad
  ///   API key must not look like being offline), and neither does a failed
  ///   page after the first (the cached feed is always page 1).
  Future<Result<PaginatedArticles>> getTopHeadlines({
    required NewsCategory category,
    required int page,
    required bool forceRefresh,
  });

  /// Searches all articles for [query].
  ///
  /// [query] must be trimmed and non-blank; callers never search for a
  /// blank query. [page] is 1-based and must be at least 1.
  ///
  /// Network only: search results are not persisted, so there is no offline
  /// fallback and `isFromCache` is always `false`. If the device reports no
  /// connection, returns `failures.NetworkFailure` without asking the
  /// network. Failures: `failures.NetworkFailure`, `failures.ServerFailure`,
  /// `failures.UnauthorizedFailure` or `failures.UnexpectedFailure`.
  Future<Result<PaginatedArticles>> searchArticles({
    required String query,
    required int page,
  });

  /// Bookmarks [article] if it is not bookmarked, otherwise removes the
  /// bookmark. Bookmarks are matched by `Article.url` (D11).
  ///
  /// Returns the new state: `Success(true)` when the article is now
  /// bookmarked (stored in full, so it can be read offline), and
  /// `Success(false)` when the bookmark was removed. On
  /// `failures.CacheFailure` or `failures.UnexpectedFailure` nothing has
  /// changed.
  Future<Result<bool>> toggleBookmark(Article article);

  /// Whether the article with [url] is bookmarked.
  ///
  /// Reads local storage only. Failures: `failures.CacheFailure` or
  /// `failures.UnexpectedFailure`.
  Future<Result<bool>> isBookmarked(String url);
}
