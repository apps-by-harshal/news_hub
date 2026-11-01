import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/data/mappers/article_mapper.dart';
import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';
import 'package:news_hub/features/news_feed/data/models/article_model.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../fixtures/fixture_reader.dart';

const String url = 'https://example.com/news/a';

/// Parses [json] as an [ArticleModel] and maps it.
Article? mapJson(Map<String, Object?> json) =>
    ArticleModel.fromJson(json).toEntityOrNull();

/// `buildArticleJson(url)` with [key] set to [value].
Map<String, Object?> jsonWith(String key, Object? value) =>
    buildArticleJson(url)..[key] = value;

/// `buildArticleJson(url)` with [key] removed.
Map<String, Object?> jsonWithout(String key) =>
    buildArticleJson(url)..remove(key);

/// `buildArticleJson(url)` with the source's [key] set to [value].
Map<String, Object?> jsonWithSource(String key, Object? value) => jsonWith(
  'source',
  <String, Object?>{'id': 'Source id of $url', 'name': 'Source of $url'}
    ..[key] = value,
);

/// `buildArticle(url)` with [publishedAt] instead of
/// [builtArticlePublishedAt].
Article buildArticlePublishedAt(DateTime publishedAt) => Article(
  url: url,
  title: 'Title of $url',
  source: const ArticleSource(id: 'Source id of $url', name: 'Source of $url'),
  publishedAt: publishedAt,
  author: 'Author of $url',
  description: 'Description of $url',
  content: 'Content of $url',
  imageUrl: '$url/image.jpg',
);

/// The fields of [model] in declaration order. `ArticleLocalModel` has no
/// `==` (plain class), so tests compare these lists instead.
List<Object?> localFields(ArticleLocalModel model) => <Object?>[
  model.url,
  model.title,
  model.sourceId,
  model.sourceName,
  model.publishedAt,
  model.author,
  model.description,
  model.content,
  model.imageUrl,
];

void main() {
  group('toEntityOrNull: valid articles', () {
    test('maps every field and renames urlToImage to imageUrl', () {
      expect(mapJson(buildArticleJson(url)), buildArticle(url));
    });

    test('keeps null optional fields as null', () {
      final Map<String, Object?> json = buildArticleJson(url)
        ..['source'] = <String, Object?>{'id': null, 'name': 'Source of $url'}
        ..['author'] = null
        ..['description'] = null
        ..['urlToImage'] = null
        ..['content'] = null;

      expect(
        mapJson(json),
        Article(
          url: url,
          title: 'Title of $url',
          source: const ArticleSource(id: null, name: 'Source of $url'),
          publishedAt: builtArticlePublishedAt,
          author: null,
          description: null,
          content: null,
          imageUrl: null,
        ),
      );
    });

    test('trims the required fields', () {
      final Map<String, Object?> json = buildArticleJson(url)
        ..['url'] = '  $url  '
        ..['title'] = '\tTitle of $url\n'
        ..['source'] = <String, Object?>{
          'id': 'Source id of $url',
          'name': ' Source of $url ',
        };

      final Article? article = mapJson(json);

      expect(article?.url, url);
      expect(article?.title, 'Title of $url');
      expect(article?.source.name, 'Source of $url');
    });

    test('trims the optional fields', () {
      final Map<String, Object?> json = buildArticleJson(url)
        ..['source'] = <String, Object?>{
          'id': ' Source id of $url ',
          'name': 'Source of $url',
        }
        ..['author'] = ' Author of $url '
        ..['description'] = ' Description of $url '
        ..['urlToImage'] = ' $url/image.jpg '
        ..['content'] = ' Content of $url ';

      expect(mapJson(json), buildArticle(url));
    });

    final Map<String, String? Function(Article)> optionalFields =
        <String, String? Function(Article)>{
          'author': (Article a) => a.author,
          'description': (Article a) => a.description,
          'content': (Article a) => a.content,
          'urlToImage': (Article a) => a.imageUrl,
        };

    for (final MapEntry<String, String? Function(Article)> field
        in optionalFields.entries) {
      test('turns a blank ${field.key} into null', () {
        final Article? article = mapJson(jsonWith(field.key, '   '));

        expect(article, isNotNull);
        expect(field.value(article!), isNull);
      });
    }

    test('turns a blank source id into null', () {
      final Article? article = mapJson(jsonWithSource('id', ''));

      expect(
        article?.source,
        const ArticleSource(id: null, name: 'Source of $url'),
      );
    });
  });

  group('toEntityOrNull: dropped articles', () {
    for (final String key in <String>[
      'url',
      'title',
      'source',
      'publishedAt',
    ]) {
      test('drops the article when $key is null', () {
        expect(mapJson(jsonWith(key, null)), isNull);
      });

      test('drops the article when $key is missing', () {
        expect(mapJson(jsonWithout(key)), isNull);
      });
    }

    test('drops the article when source.name is null', () {
      expect(mapJson(jsonWithSource('name', null)), isNull);
    });

    test('drops the article when source.name is missing', () {
      expect(
        mapJson(jsonWith('source', <String, Object?>{'id': 'Source id'})),
        isNull,
      );
    });

    for (final String blank in <String>['', '   ']) {
      test('drops the article when url is "$blank"', () {
        expect(mapJson(jsonWith('url', blank)), isNull);
      });

      test('drops the article when title is "$blank"', () {
        expect(mapJson(jsonWith('title', blank)), isNull);
      });

      test('drops the article when source.name is "$blank"', () {
        expect(mapJson(jsonWithSource('name', blank)), isNull);
      });
    }

    for (final String title in <String>['[Removed]', '  [Removed] ']) {
      test('drops the placeholder title "$title"', () {
        expect(mapJson(jsonWith('title', title)), isNull);
      });
    }

    for (final String removed in <String>[
      'https://removed.com',
      'http://removed.com/',
    ]) {
      test('drops the placeholder url $removed', () {
        expect(mapJson(jsonWith('url', removed)), isNull);
      });
    }

    for (final String invalid in <String>[
      'not a url',
      'ftp://example.com/a',
      '/news/a',
      'https://',
    ]) {
      test('drops the article when url is "$invalid"', () {
        expect(mapJson(jsonWith('url', invalid)), isNull);
      });
    }

    for (final String invalid in <String>['yesterday', '', '30/10/2026']) {
      test('drops the article when publishedAt is "$invalid"', () {
        expect(mapJson(jsonWith('publishedAt', invalid)), isNull);
      });
    }
  });

  group('toEntityOrNull: urlToImage', () {
    for (final String invalid in <String>[
      'not a url',
      'ftp://example.com/a.jpg',
    ]) {
      test('turns an invalid urlToImage "$invalid" into null and keeps the '
          'article', () {
        final Article? article = mapJson(jsonWith('urlToImage', invalid));

        expect(article, isNotNull);
        expect(article?.imageUrl, isNull);
        expect(article?.url, url);
      });
    }
  });

  group('toEntityOrNull: publishedAt', () {
    test('keeps a Z timestamp in UTC', () {
      final Article? article = mapJson(
        jsonWith('publishedAt', '2026-10-30T08:30:00Z'),
      );

      expect(article?.publishedAt, DateTime.utc(2026, 10, 30, 8, 30));
      expect(article?.publishedAt.isUtc, isTrue);
    });

    test('converts a +05:30 offset to UTC', () {
      final Article? article = mapJson(
        jsonWith('publishedAt', '2026-10-30T11:00:00+05:30'),
      );

      expect(article?.publishedAt, DateTime.utc(2026, 10, 30, 5, 30));
      expect(article?.publishedAt.isUtc, isTrue);
    });

    test('converts a -04:00 offset to UTC', () {
      final Article? article = mapJson(
        jsonWith('publishedAt', '2026-10-30T04:30:00-04:00'),
      );

      expect(article?.publishedAt, DateTime.utc(2026, 10, 30, 8, 30));
      expect(article?.publishedAt.isUtc, isTrue);
    });

    test('reads a timestamp without an offset as UTC, not local time', () {
      final Article? article = mapJson(
        jsonWith('publishedAt', '2026-10-30T08:30:00'),
      );

      expect(article?.publishedAt, DateTime.utc(2026, 10, 30, 8, 30));
      expect(article?.publishedAt.isUtc, isTrue);
    });

    test('keeps fractional seconds of a timestamp without an offset', () {
      final Article? article = mapJson(
        jsonWith('publishedAt', '2026-10-30T08:30:00.123456'),
      );

      expect(
        article?.publishedAt,
        DateTime.utc(2026, 10, 30, 8, 30, 0, 123, 456),
      );
    });
  });

  group('toEntityOrNull: content', () {
    test('strips a trailing truncation marker and keeps the ellipsis', () {
      final Article? article = mapJson(
        jsonWith('content', 'The final ended level… [+2345 chars]'),
      );

      expect(article?.content, 'The final ended level…');
    });

    test('turns content that is only a marker into null', () {
      final Article? article = mapJson(jsonWith('content', '[+2345 chars]'));

      expect(article, isNotNull);
      expect(article?.content, isNull);
    });

    test('leaves a marker in the middle of the text alone', () {
      final Article? article = mapJson(
        jsonWith('content', 'See [+12 chars] for more'),
      );

      expect(article?.content, 'See [+12 chars] for more');
    });
  });

  group('toEntities', () {
    test('keeps the order and skips articles that are dropped', () {
      const String a = 'https://example.com/news/a';
      const String b = 'https://example.com/news/b';
      const String c = 'https://example.com/news/c';

      final List<ArticleModel> models = <ArticleModel>[
        ArticleModel.fromJson(buildArticleJson(c)),
        ArticleModel.fromJson(buildArticleJson(a)..['title'] = null),
        ArticleModel.fromJson(buildArticleJson(a)),
        ArticleModel.fromJson(buildArticleJson('https://removed.com')),
        ArticleModel.fromJson(buildArticleJson(b)),
      ];

      expect(models.toEntities(), <Article>[
        buildArticle(c),
        buildArticle(a),
        buildArticle(b),
      ]);
    });

    test('maps an empty list to an empty list', () {
      expect(<ArticleModel>[].toEntities(), isEmpty);
    });
  });

  group('toRemoteArticlesPage', () {
    test('maps the top-headlines fixture to its 4 valid articles', () {
      final RemoteArticlesPage page = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json'),
      ).toRemoteArticlesPage();

      expect(
        page,
        RemoteArticlesPage(
          articles: <Article>[
            Article(
              url: 'https://example.com/news/markets-rally',
              title: 'Markets rally as inflation cools',
              source: const ArticleSource(
                id: 'example-news',
                name: 'Example News',
              ),
              publishedAt: DateTime.utc(2026, 10, 30, 8, 30),
              author: 'Jane Doe',
              description:
                  'Stocks rose for a third day after new figures showed '
                  'prices easing.',
              content: 'Stocks rose for a third straight day on Thursday.',
              imageUrl: 'https://example.com/images/markets-rally.jpg',
            ),
            Article(
              url: 'https://techdaily.example.org/2026/10/folding-phone',
              title: 'New folding phone announced',
              source: const ArticleSource(id: null, name: 'Tech Daily'),
              publishedAt: DateTime.utc(2026, 10, 30, 7, 15),
              author: null,
              description: null,
              content: null,
              imageUrl: null,
            ),
            Article(
              url: 'https://indiatimes.example.in/politics/session-opens',
              title: 'Winter session opens in parliament',
              source: const ArticleSource(
                id: null,
                name: 'India Times Example',
              ),
              publishedAt: DateTime.utc(2026, 10, 30, 5, 30),
              author: 'Priya Shah',
              description: 'Lawmakers return for the winter sitting.',
              content: 'The session opened on Friday morning.',
              imageUrl: 'https://indiatimes.example.in/images/session.jpg',
            ),
            Article(
              url: 'https://sportscentral.example.com/final-draw',
              title: 'Championship final ends in a draw',
              source: const ArticleSource(
                id: 'sports-central',
                name: 'Sports Central',
              ),
              publishedAt: DateTime.utc(2026, 10, 29, 21, 45),
              author: 'Alex Kim',
              description: 'Neither side found a winner after extra time.',
              content: 'The championship final ended level after extra time…',
              imageUrl: 'https://sportscentral.example.com/images/final.jpg',
            ),
          ],
          totalResults: 38,
        ),
      );
    });

    test('maps the empty fixture to no articles and a total of 0', () {
      final RemoteArticlesPage page = NewsResponseModel.fromJson(
        fixtureJson('empty_response.json'),
      ).toRemoteArticlesPage();

      expect(
        page,
        RemoteArticlesPage(articles: const <Article>[], totalResults: 0),
      );
    });

    test('maps null articles and a null total to an empty page', () {
      final RemoteArticlesPage page = NewsResponseModel.fromJson(
        fixtureJson('error_response.json'),
      ).toRemoteArticlesPage();

      expect(
        page,
        RemoteArticlesPage(articles: const <Article>[], totalResults: 0),
      );
    });

    test('clamps a negative total to 0', () {
      final RemoteArticlesPage page = NewsResponseModel.fromJson(
        <String, Object?>{
          'status': 'ok',
          'totalResults': -5,
          'articles': <Object?>[buildArticleJson(url)],
        },
      ).toRemoteArticlesPage();

      expect(
        page,
        RemoteArticlesPage(
          articles: <Article>[buildArticle(url)],
          totalResults: 0,
        ),
      );
    });
  });

  group('toLocalModel', () {
    test('copies every field and flattens the source', () {
      expect(localFields(buildArticle(url).toLocalModel()), <Object?>[
        url,
        'Title of $url',
        'Source id of $url',
        'Source of $url',
        builtArticlePublishedAt,
        'Author of $url',
        'Description of $url',
        'Content of $url',
        '$url/image.jpg',
      ]);
    });

    test('keeps null optional fields as null', () {
      expect(
        localFields(buildArticleWithoutOptionals(url).toLocalModel()),
        <Object?>[
          url,
          'Title of $url',
          null,
          'Source of $url',
          builtArticlePublishedAt,
          null,
          null,
          null,
          null,
        ],
      );
    });

    test('keeps publishedAt in UTC with its microseconds', () {
      final DateTime instant = DateTime.utc(2026, 10, 30, 8, 30, 0, 123, 456);

      final ArticleLocalModel model = buildArticlePublishedAt(instant)
          .toLocalModel();

      expect(model.publishedAt, instant);
      expect(model.publishedAt.isUtc, isTrue);
      expect(model.publishedAt.microsecond, 456);
    });
  });

  group('toEntity', () {
    test('copies every field and rebuilds the source', () {
      final ArticleLocalModel model = ArticleLocalModel(
        url: url,
        title: 'Title of $url',
        sourceId: 'Source id of $url',
        sourceName: 'Source of $url',
        publishedAt: builtArticlePublishedAt,
        author: 'Author of $url',
        description: 'Description of $url',
        content: 'Content of $url',
        imageUrl: '$url/image.jpg',
      );

      expect(model.toEntity(), buildArticle(url));
    });

    test('keeps null optional fields as null', () {
      final ArticleLocalModel model = ArticleLocalModel(
        url: url,
        title: 'Title of $url',
        sourceId: null,
        sourceName: 'Source of $url',
        publishedAt: builtArticlePublishedAt,
        author: null,
        description: null,
        content: null,
        imageUrl: null,
      );

      expect(model.toEntity(), buildArticleWithoutOptionals(url));
    });
  });

  group('local round trip', () {
    final Map<String, Article> articles = <String, Article>{
      'every field set': buildArticle(url),
      'every optional field null': buildArticleWithoutOptionals(url),
      'microseconds in publishedAt': buildArticlePublishedAt(
        DateTime.utc(2026, 10, 30, 8, 30, 0, 123, 456),
      ),
    };

    for (final MapEntry<String, Article> entry in articles.entries) {
      test('round-trips an article with ${entry.key}', () {
        expect(entry.value.toLocalModel().toEntity(), entry.value);
      });
    }
  });
}
