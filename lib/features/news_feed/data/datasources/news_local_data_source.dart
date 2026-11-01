import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

/// Local (on-device) store for the offline feed cache and bookmarks.
///
/// Speaks entities: the implementation (`NewsLocalDataSourceImpl`, Step 19)
/// maps to and from the Hive local models, so callers never see a model.
///
/// Two independent stores:
/// - **Feed cache**, one list of articles per [NewsCategory], used by the
///   repository's network-first fallback (D12). Each category is written as a
///   single list, so an article in two categories is stored twice.
/// - **Bookmarks**, identified by `Article.url` (D1), each stored in full so
///   it can be read offline. The URL is not used as the storage key: Hive
///   limits String keys to 255 UTF-8 bytes and only checks that in debug
///   builds, so a long URL could corrupt the store in release. Bookmarks are
///   stored under auto-increment keys and found by URL (Step 19). Clearing
///   or replacing the feed cache never touches bookmarks.
///
/// Every method throws `CacheException` when the underlying storage fails.
/// The repository maps it to `CacheFailure` (D9).
abstract interface class NewsLocalDataSource {
  /// Stores [articles] as page [page] of the cached feed for [category].
  ///
  /// - `page == 1` replaces the category's cached list with [articles].
  /// - `page > 1` appends [articles] to the cached list. An article whose URL
  ///   is already cached replaces the cached copy in its current position
  ///   (fresher data, stable order); new URLs are added at the end in the
  ///   given order.
  ///
  /// Precondition: `page >= 1`.
  Future<void> cacheTopHeadlines({
    required NewsCategory category,
    required int page,
    required List<Article> articles,
  });

  /// Returns the cached feed for [category] in stored order, or an empty list
  /// when nothing has been cached for it.
  Future<List<Article>> getCachedTopHeadlines(NewsCategory category);

  /// Stores [article] as a bookmark, identified by its URL. Overwrites an
  /// existing bookmark with the same URL in place.
  Future<void> saveBookmark(Article article);

  /// Removes the bookmark for [url]. Does nothing if there is none.
  Future<void> removeBookmark(String url);

  /// Whether a bookmark exists for [url].
  Future<bool> isBookmarked(String url);
}
