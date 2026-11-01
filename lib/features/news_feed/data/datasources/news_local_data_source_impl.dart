import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/core/storage/storage_guard.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source.dart';
import 'package:news_hub/features/news_feed/data/mappers/article_mapper.dart';
import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';
import 'package:news_hub/features/news_feed/data/models/cached_articles_local_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

/// Hive box holding one [CachedArticlesLocalModel] per category key.
/// Persisted name: renaming it orphans every user's cached feed.
const String _cacheBoxName = 'articles_cache';

/// Hive box holding one [ArticleLocalModel] per bookmark, under
/// auto-increment keys. Persisted name: renaming it loses every bookmark.
const String _bookmarksBoxName = 'bookmarks';

/// [NewsLocalDataSource] over Hive, through the app's [LocalDatabase]
/// (Step 19, D13, D15).
///
/// - Boxes are opened on every call ([LocalDatabase.openBox] returns the
///   already-open box), and every call runs inside [guardStorageCall], so a
///   storage failure surfaces as `CacheException`, never as a crash at
///   startup.
/// - **Feed cache:** one value per category under a fixed key from an
///   exhaustive `switch` (never `.name`). Each write merges into a list
///   that holds at most one entry per URL, then stores it with one `put`.
/// - **Bookmarks:** stored under auto-increment int keys and found by URL.
///   The URL is not the key because Hive limits String keys to 255 UTF-8
///   bytes and checks that only in debug builds. Lookups scan the open box
///   in memory, which is fine for a user's bookmark count. The list is read
///   newest first: reverse key order (Step 24).
final class NewsLocalDataSourceImpl implements NewsLocalDataSource {
  /// Creates the data source. [localDatabase] must have completed `init()`.
  const NewsLocalDataSourceImpl({required this._localDatabase});

  final LocalDatabase _localDatabase;

  @override
  Future<void> cacheTopHeadlines({
    required NewsCategory category,
    required int page,
    required List<Article> articles,
  }) async {
    assert(page >= 1, 'page must be >= 1');
    await guardStorageCall<void>(() async {
      final Box<CachedArticlesLocalModel> box = await _cacheBox();
      final String key = _cacheKey(category);
      final List<ArticleLocalModel> merged = page == 1
          ? <ArticleLocalModel>[]
          : List<ArticleLocalModel>.of(
              box.get(key)?.articles ?? const <ArticleLocalModel>[],
            );
      final Map<String, int> indexByUrl = <String, int>{
        for (int i = 0; i < merged.length; i++) merged[i].url: i,
      };
      for (final Article article in articles) {
        final ArticleLocalModel model = article.toLocalModel();
        final int? index = indexByUrl[model.url];
        if (index == null) {
          indexByUrl[model.url] = merged.length;
          merged.add(model);
        } else {
          merged[index] = model;
        }
      }
      await box.put(key, CachedArticlesLocalModel(articles: merged));
    });
  }

  @override
  Future<List<Article>> getCachedTopHeadlines(
    NewsCategory category,
  ) => guardStorageCall<List<Article>>(() async {
    final Box<CachedArticlesLocalModel> box = await _cacheBox();
    final List<ArticleLocalModel> stored =
        box.get(_cacheKey(category))?.articles ?? const <ArticleLocalModel>[];
    return stored.map((ArticleLocalModel model) => model.toEntity()).toList();
  });

  @override
  Future<void> saveBookmark(Article article) =>
      guardStorageCall<void>(() async {
        final Box<ArticleLocalModel> box = await _bookmarksBox();
        final ArticleLocalModel model = article.toLocalModel();
        final Object? existingKey = _keysFor(box, article.url).firstOrNull;
        if (existingKey == null) {
          await box.add(model);
        } else {
          await box.put(existingKey, model);
        }
      });

  @override
  Future<void> removeBookmark(String url) => guardStorageCall<void>(() async {
    final Box<ArticleLocalModel> box = await _bookmarksBox();
    final List<Object?> keys = _keysFor(box, url).toList();
    if (keys.isNotEmpty) {
      await box.deleteAll(keys);
    }
  });

  @override
  Future<bool> isBookmarked(String url) => guardStorageCall<bool>(() async {
    final Box<ArticleLocalModel> box = await _bookmarksBox();
    return _keysFor(box, url).isNotEmpty;
  });

  @override
  Future<List<Article>> getBookmarks() =>
      guardStorageCall<List<Article>>(() async {
        final Box<ArticleLocalModel> box = await _bookmarksBox();
        // Values come back in key order, and add() hands out ascending keys,
        // so reversing gives the most recently saved bookmark first.
        return box.values
            .toList()
            .reversed
            .map((ArticleLocalModel model) => model.toEntity())
            .toList();
      });

  Future<Box<CachedArticlesLocalModel>> _cacheBox() =>
      _localDatabase.openBox<CachedArticlesLocalModel>(_cacheBoxName);

  Future<Box<ArticleLocalModel>> _bookmarksBox() =>
      _localDatabase.openBox<ArticleLocalModel>(_bookmarksBoxName);
}

/// The keys of the bookmarks stored for [url] (at most one in practice).
Iterable<Object?> _keysFor(Box<ArticleLocalModel> box, String url) =>
    box.keys.where((Object? key) => box.get(key)?.url == url);

/// The persisted `articles_cache` key for [category]. Exhaustive, no
/// default: a new [NewsCategory] does not compile until its key is chosen.
/// Never change an existing key: it would orphan that category's cache.
String _cacheKey(NewsCategory category) => switch (category) {
  NewsCategory.general => 'general',
  NewsCategory.business => 'business',
  NewsCategory.entertainment => 'entertainment',
  NewsCategory.health => 'health',
  NewsCategory.science => 'science',
  NewsCategory.sports => 'sports',
  NewsCategory.technology => 'technology',
};
