/// App-wide constants that are not environment-specific.
///
/// Environment values (base URL, API key, logging) live in `AppConfig`.
/// Values here are added when something first uses them.
abstract final class AppConstants {
  /// Time allowed to open a connection to the API.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Time allowed to send a request body.
  static const Duration sendTimeout = Duration(seconds: 10);

  /// Time allowed between bytes while receiving a response.
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// How long a cached HTTP response is served before the API is asked
  /// again (`CacheOptions.maxStale` with `CachePolicy.forceCache`).
  ///
  /// Keeps repeated identical requests off NewsAPI's free daily quota while
  /// headlines stay reasonably fresh. Offline reading is Hive's job, not
  /// this cache's (CLAUDE.md §3.5).
  static const Duration httpCacheMaxStale = Duration(minutes: 10);

  /// Number of articles requested per page from NewsAPI (`pageSize`).
  ///
  /// The repository passes it to the remote data source and uses it to work
  /// out `PaginatedArticles.hasMore` (D11).
  static const int newsPageSize = 20;

  /// The most results NewsAPI's free Developer plan returns for one query.
  ///
  /// Requesting a page that starts past this many results is rejected by
  /// the API, so `hasMore` is `false` once `page * newsPageSize` reaches
  /// `min(totalResults, newsMaxResults)` (D11).
  static const int newsMaxResults = 100;
}
