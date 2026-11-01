import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/features/news_feed/data/mappers/article_mapper.dart';
import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';
import 'package:news_hub/features/news_feed/data/models/cached_articles_local_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';
import 'package:news_hub/hive_adapters.dart';
import 'package:news_hub/hive_registrar.g.dart';

import 'fixtures/article_builders.dart';

const String url = 'https://example.com/news/a';

/// Writes [value] under [key], closes the box and reads the value back from
/// disk. An open box answers reads from memory, so closing and reopening is
/// what makes the read go through the generated adapter.
Future<T?> roundTrip<T>(String boxName, String key, T value) async {
  final Box<T> box = await Hive.openBox<T>(boxName);
  await box.put(key, value);
  await box.close();

  final Box<T> reopened = await Hive.openBox<T>(boxName);
  return reopened.get(key);
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    // Registering an adapter twice throws a HiveError, so once per file.
    Hive.registerAdapters();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('news_hub_hive_adapters_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('type ids (pinned by lib/hive_adapters.g.yaml)', () {
    test('ArticleLocalModel has type id 0', () {
      expect(ArticleLocalModelAdapter().typeId, 0);
    });

    test('CachedArticlesLocalModel has type id 1', () {
      expect(CachedArticlesLocalModelAdapter().typeId, 1);
    });

    test('adapters are equal by type and type id', () {
      expect(ArticleLocalModelAdapter(), ArticleLocalModelAdapter());
      expect(
        ArticleLocalModelAdapter().hashCode,
        ArticleLocalModelAdapter().hashCode,
      );
      expect(
        CachedArticlesLocalModelAdapter(),
        CachedArticlesLocalModelAdapter(),
      );
      expect(
        CachedArticlesLocalModelAdapter().hashCode,
        CachedArticlesLocalModelAdapter().hashCode,
      );
      expect(
        ArticleLocalModelAdapter(),
        isNot(CachedArticlesLocalModelAdapter()),
      );
      expect(
        CachedArticlesLocalModelAdapter(),
        isNot(ArticleLocalModelAdapter()),
      );
    });
  });

  group('registrar (lib/hive_registrar.g.dart)', () {
    test('Hive.registerAdapters registers both adapters', () {
      // Called once in setUpAll.
      expect(Hive.isAdapterRegistered(0), isTrue);
      expect(Hive.isAdapterRegistered(1), isTrue);
    });

    test('IsolatedHive.registerAdapters registers both adapters', () {
      // The app uses plain Hive; this covers the generated IsolatedHive
      // extension, which needs no IsolatedHive.init to register adapters.
      IsolatedHive.registerAdapters();

      expect(IsolatedHive.isAdapterRegistered(0), isTrue);
      expect(IsolatedHive.isAdapterRegistered(1), isTrue);
    });
  });

  group('ArticleLocalModel round trip through disk', () {
    test('keeps every field', () async {
      final ArticleLocalModel? read = await roundTrip<ArticleLocalModel>(
        'bookmarks_test',
        url,
        buildArticle(url).toLocalModel(),
      );

      expect(read?.toEntity(), buildArticle(url));
    });

    test('keeps every optional field null', () async {
      final ArticleLocalModel? read = await roundTrip<ArticleLocalModel>(
        'bookmarks_test',
        url,
        buildArticleWithoutOptionals(url).toLocalModel(),
      );

      expect(read?.toEntity(), buildArticleWithoutOptionals(url));
    });

    test('keeps publishedAt in UTC with its microseconds', () async {
      final DateTime instant = DateTime.utc(2026, 10, 30, 8, 30, 0, 123, 456);
      final Article article = Article(
        url: url,
        title: 'Title of $url',
        source: const ArticleSource(id: null, name: 'Source of $url'),
        publishedAt: instant,
        author: null,
        description: null,
        content: null,
        imageUrl: null,
      );

      final ArticleLocalModel? read = await roundTrip<ArticleLocalModel>(
        'bookmarks_test',
        url,
        article.toLocalModel(),
      );

      expect(read?.publishedAt, instant);
      expect(read?.publishedAt.isUtc, isTrue);
      expect(read?.publishedAt.microsecond, 456);
    });
  });

  group('CachedArticlesLocalModel round trip through disk', () {
    test('keeps the articles, their order and the list type', () async {
      const String a = 'https://example.com/news/a';
      const String b = 'https://example.com/news/b';
      const String c = 'https://example.com/news/c';
      final List<Article> articles = <Article>[
        buildArticle(b),
        buildArticleWithoutOptionals(a),
        buildArticle(c),
      ];

      final CachedArticlesLocalModel? read =
          await roundTrip<CachedArticlesLocalModel>(
            'articles_cache_test',
            'general',
            CachedArticlesLocalModel(
              articles: articles
                  .map((Article article) => article.toLocalModel())
                  .toList(),
            ),
          );

      expect(read?.articles, isA<List<ArticleLocalModel>>());
      expect(
        read?.articles
            .map((ArticleLocalModel model) => model.toEntity())
            .toList(),
        articles,
      );
    });

    test('reads an empty list back as an empty typed list', () async {
      final CachedArticlesLocalModel? read =
          await roundTrip<CachedArticlesLocalModel>(
            'articles_cache_test',
            'general',
            const CachedArticlesLocalModel(articles: <ArticleLocalModel>[]),
          );

      expect(read?.articles, isA<List<ArticleLocalModel>>());
      expect(read?.articles, isEmpty);
    });
  });
}
