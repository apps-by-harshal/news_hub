import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/core/storage/local_database_impl.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source_impl.dart';
import 'package:news_hub/features/news_feed/data/mappers/article_mapper.dart';
import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';
import 'package:news_hub/features/news_feed/data/models/cached_articles_local_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/hive_registrar.g.dart';

import '../../../../fixtures/article_builders.dart';

// Box names and cache keys are persisted data: they are written out here on
// purpose, so renaming one (which would orphan users' stored data) breaks a
// test.
const String _cacheBoxName = 'articles_cache';
const String _bookmarksBoxName = 'bookmarks';

const String _urlA = 'https://example.com/news/a';
const String _urlB = 'https://example.com/news/b';
const String _urlC = 'https://example.com/news/c';
const String _urlD = 'https://example.com/news/d';

List<Article> _articles(List<String> urls) => urls.map(buildArticle).toList();

void main() {
  late Directory tempDir;
  late NewsLocalDataSource dataSource;

  setUpAll(() {
    // Once per file: Hive rejects a second registration of a type id.
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('news_hub_local_ds_');
    final LocalDatabase database = LocalDatabaseImpl(
      hive: Hive,
      initialize: () async {
        Hive.init(tempDir.path);
      },
      registerAdapters: () {},
    );
    await database.init();
    dataSource = NewsLocalDataSourceImpl(localDatabase: database);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> cachePage(
    int page,
    List<Article> articles, {
    NewsCategory category = NewsCategory.general,
  }) => dataSource.cacheTopHeadlines(
    category: category,
    page: page,
    articles: articles,
  );

  Future<List<Article>> cached([
    NewsCategory category = NewsCategory.general,
  ]) => dataSource.getCachedTopHeadlines(category);

  /// The bookmarks as stored, in key order, mapped back to entities.
  Future<List<Article>> storedBookmarks() async {
    final Box<ArticleLocalModel> box = await Hive.openBox<ArticleLocalModel>(
      _bookmarksBoxName,
    );
    return box.values
        .map((ArticleLocalModel model) => model.toEntity())
        .toList();
  }

  group('feed cache', () {
    test('returns an empty list for a category never cached', () async {
      expect(await cached(), isEmpty);
    });

    test('page 1 stores the articles in order', () async {
      await cachePage(1, _articles(<String>[_urlA, _urlB, _urlC]));

      expect(await cached(), _articles(<String>[_urlA, _urlB, _urlC]));
    });

    test('page 1 replaces the cached list', () async {
      await cachePage(1, _articles(<String>[_urlA, _urlB]));
      await cachePage(1, _articles(<String>[_urlC]));

      expect(await cached(), _articles(<String>[_urlC]));
    });

    test('page 1 with no articles clears the category', () async {
      await cachePage(1, _articles(<String>[_urlA]));
      await cachePage(1, <Article>[]);

      expect(await cached(), isEmpty);
    });

    test('a later page appends in order', () async {
      await cachePage(1, _articles(<String>[_urlA, _urlB]));
      await cachePage(2, _articles(<String>[_urlC, _urlD]));

      expect(await cached(), _articles(<String>[_urlA, _urlB, _urlC, _urlD]));
    });

    test('a later page replaces an already-cached URL in place and appends '
        'new ones', () async {
      await cachePage(1, _articles(<String>[_urlA, _urlB, _urlC]));
      final Article fresherB = buildArticleWithoutOptionals(_urlB);
      await cachePage(2, <Article>[fresherB, buildArticle(_urlD)]);

      expect(await cached(), <Article>[
        buildArticle(_urlA),
        fresherB,
        buildArticle(_urlC),
        buildArticle(_urlD),
      ]);
    });

    test('a URL repeated within one page keeps its first position and its '
        'last value', () async {
      final Article laterA = buildArticleWithoutOptionals(_urlA);
      await cachePage(1, <Article>[
        buildArticle(_urlA),
        buildArticle(_urlB),
        laterA,
      ]);

      expect(await cached(), <Article>[laterA, buildArticle(_urlB)]);
    });

    test('categories are cached independently', () async {
      await cachePage(1, _articles(<String>[_urlA]));
      await cachePage(
        1,
        _articles(<String>[_urlB]),
        category: NewsCategory.business,
      );

      expect(await cached(), _articles(<String>[_urlA]));
      expect(await cached(NewsCategory.business), _articles(<String>[_urlB]));
      expect(await cached(NewsCategory.health), isEmpty);
    });

    test('stores each category under its fixed key', () async {
      for (final NewsCategory category in NewsCategory.values) {
        await cachePage(
          1,
          _articles(<String>['https://example.com/${category.name}']),
          category: category,
        );
      }

      final Box<CachedArticlesLocalModel> box =
          await Hive.openBox<CachedArticlesLocalModel>(_cacheBoxName);
      expect(
        box.keys,
        unorderedEquals(<String>[
          'general',
          'business',
          'entertainment',
          'health',
          'science',
          'sports',
          'technology',
        ]),
      );
      for (final NewsCategory category in NewsCategory.values) {
        expect(
          await cached(category),
          _articles(<String>['https://example.com/${category.name}']),
          reason: category.name,
        );
      }
    });

    test('survives closing and reopening the box', () async {
      final List<Article> articles = <Article>[
        buildArticle(_urlA),
        buildArticleWithoutOptionals(_urlB),
      ];
      await cachePage(1, articles);

      // An open box answers from memory; reopening reads through the adapter.
      await Hive.close();

      expect(await cached(), articles);
    });

    test('never touches bookmarks', () async {
      await dataSource.saveBookmark(buildArticle(_urlA));

      await cachePage(1, _articles(<String>[_urlA, _urlB]));
      await cachePage(1, <Article>[]);

      expect(await dataSource.isBookmarked(_urlA), isTrue);
    });

    test('rejects a page below 1', () async {
      await expectLater(
        cachePage(0, _articles(<String>[_urlA])),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('bookmarks', () {
    test('isBookmarked is false when nothing is saved', () async {
      expect(await dataSource.isBookmarked(_urlA), isFalse);
    });

    test('saveBookmark stores the article in full', () async {
      await dataSource.saveBookmark(buildArticle(_urlA));

      expect(await dataSource.isBookmarked(_urlA), isTrue);
      expect(await dataSource.isBookmarked(_urlB), isFalse);
      expect(await storedBookmarks(), <Article>[buildArticle(_urlA)]);
    });

    test('saving the same URL again overwrites it in place', () async {
      final Article fresherA = buildArticleWithoutOptionals(_urlA);
      await dataSource.saveBookmark(buildArticle(_urlA));
      await dataSource.saveBookmark(buildArticle(_urlB));
      await dataSource.saveBookmark(fresherA);

      expect(await storedBookmarks(), <Article>[fresherA, buildArticle(_urlB)]);
    });

    test('removeBookmark removes only that URL', () async {
      await dataSource.saveBookmark(buildArticle(_urlA));
      await dataSource.saveBookmark(buildArticle(_urlB));

      await dataSource.removeBookmark(_urlA);

      expect(await dataSource.isBookmarked(_urlA), isFalse);
      expect(await dataSource.isBookmarked(_urlB), isTrue);
      expect(await storedBookmarks(), <Article>[buildArticle(_urlB)]);
    });

    test('removeBookmark of an unknown URL does nothing', () async {
      await dataSource.saveBookmark(buildArticle(_urlA));

      await dataSource.removeBookmark(_urlB);

      expect(await storedBookmarks(), <Article>[buildArticle(_urlA)]);
    });

    test('works with a URL longer than 255 characters and non-ASCII '
        'characters', () async {
      final String longUrl = 'https://example.com/news/${'ü' * 300}';
      expect(longUrl.length, greaterThan(255));

      await dataSource.saveBookmark(buildArticle(longUrl));
      await Hive.close();

      expect(await dataSource.isBookmarked(longUrl), isTrue);
      expect(await storedBookmarks(), <Article>[buildArticle(longUrl)]);

      await dataSource.removeBookmark(longUrl);

      expect(await dataSource.isBookmarked(longUrl), isFalse);
    });

    test('survive closing and reopening the box', () async {
      final Article article = buildArticleWithoutOptionals(_urlA);
      await dataSource.saveBookmark(article);

      await Hive.close();

      expect(await dataSource.isBookmarked(_urlA), isTrue);
      expect(await storedBookmarks(), <Article>[article]);
    });
  });

  group('getBookmarks', () {
    test('returns an empty list when nothing is saved', () async {
      expect(await dataSource.getBookmarks(), isEmpty);
    });

    test('returns every bookmark in full, newest first, after closing and '
        'reopening the box', () async {
      final Article withoutOptionals = buildArticleWithoutOptionals(_urlB);
      await dataSource.saveBookmark(buildArticle(_urlA));
      await dataSource.saveBookmark(withoutOptionals);
      await dataSource.saveBookmark(buildArticle(_urlC));

      // Read back through the adapter, not from the open box in memory.
      await Hive.close();

      expect(await dataSource.getBookmarks(), <Article>[
        buildArticle(_urlC),
        withoutOptionals,
        buildArticle(_urlA),
      ]);
    });

    test('drops a removed bookmark and keeps the rest in order', () async {
      await dataSource.saveBookmark(buildArticle(_urlA));
      await dataSource.saveBookmark(buildArticle(_urlB));
      await dataSource.saveBookmark(buildArticle(_urlC));

      await dataSource.removeBookmark(_urlB);

      expect(await dataSource.getBookmarks(), <Article>[
        buildArticle(_urlC),
        buildArticle(_urlA),
      ]);
    });

    test('an article bookmarked again after removal comes first', () async {
      await dataSource.saveBookmark(buildArticle(_urlA));
      await dataSource.saveBookmark(buildArticle(_urlB));
      await dataSource.removeBookmark(_urlA);

      await dataSource.saveBookmark(buildArticle(_urlA));

      expect(await dataSource.getBookmarks(), <Article>[
        buildArticle(_urlA),
        buildArticle(_urlB),
      ]);
    });
  });

  group('storage failures → CacheException', () {
    // Opening a box that is already open with another value type makes Hive
    // throw a real HiveError.
    Future<void> openCacheBoxWithWrongType() =>
        Hive.openBox<String>(_cacheBoxName);
    Future<void> openBookmarksBoxWithWrongType() =>
        Hive.openBox<String>(_bookmarksBoxName);

    test('cacheTopHeadlines', () async {
      await openCacheBoxWithWrongType();

      await expectLater(
        cachePage(1, _articles(<String>[_urlA])),
        throwsA(isA<CacheException>()),
      );
    });

    test('getCachedTopHeadlines', () async {
      await openCacheBoxWithWrongType();

      await expectLater(cached(), throwsA(isA<CacheException>()));
    });

    test('saveBookmark', () async {
      await openBookmarksBoxWithWrongType();

      await expectLater(
        dataSource.saveBookmark(buildArticle(_urlA)),
        throwsA(isA<CacheException>()),
      );
    });

    test('removeBookmark', () async {
      await openBookmarksBoxWithWrongType();

      await expectLater(
        dataSource.removeBookmark(_urlA),
        throwsA(isA<CacheException>()),
      );
    });

    test('isBookmarked', () async {
      await openBookmarksBoxWithWrongType();

      await expectLater(
        dataSource.isBookmarked(_urlA),
        throwsA(isA<CacheException>()),
      );
    });

    test('getBookmarks', () async {
      await openBookmarksBoxWithWrongType();

      await expectLater(
        dataSource.getBookmarks(),
        throwsA(isA<CacheException>()),
      );
    });
  });
}
