import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/data/models/article_model.dart';
import 'package:news_hub/features/news_feed/data/models/article_source_model.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/json_matchers.dart';

/// The [ArticleModel] that `buildArticleJson(url)` parses to.
ArticleModel expectedModel(String url) => ArticleModel(
  source: ArticleSourceModel(id: 'Source id of $url', name: 'Source of $url'),
  author: 'Author of $url',
  title: 'Title of $url',
  description: 'Description of $url',
  url: url,
  urlToImage: '$url/image.jpg',
  publishedAt: builtArticlePublishedAtJson,
  content: 'Content of $url',
);

void main() {
  const String url = 'https://example.com/news/a';

  group('ArticleModel.fromJson', () {
    test('reads every field, including the nested source', () {
      final ArticleModel model = ArticleModel.fromJson(buildArticleJson(url));

      expect(model, expectedModel(url));
    });

    test('keeps urlToImage under its API name', () {
      final ArticleModel model = ArticleModel.fromJson(buildArticleJson(url));

      expect(model.urlToImage, '$url/image.jpg');
    });

    test('reads explicit nulls as null', () {
      final ArticleModel model = ArticleModel.fromJson(<String, Object?>{
        'source': <String, Object?>{'id': null, 'name': null},
        'author': null,
        'title': null,
        'description': null,
        'url': null,
        'urlToImage': null,
        'publishedAt': null,
        'content': null,
      });

      expect(
        model,
        const ArticleModel(
          source: ArticleSourceModel(id: null, name: null),
          author: null,
          title: null,
          description: null,
          url: null,
          urlToImage: null,
          publishedAt: null,
          content: null,
        ),
      );
    });

    test('reads missing keys as null, including source', () {
      final ArticleModel model = ArticleModel.fromJson(<String, Object?>{});

      expect(
        model,
        const ArticleModel(
          source: null,
          author: null,
          title: null,
          description: null,
          url: null,
          urlToImage: null,
          publishedAt: null,
          content: null,
        ),
      );
    });

    test('reads a null source as null and keeps the other fields', () {
      final ArticleModel model = ArticleModel.fromJson(
        buildArticleJson(url)..['source'] = null,
      );

      expect(model.source, isNull);
      expect(model.url, url);
      expect(model.title, 'Title of $url');
    });

    test('keeps publishedAt as the raw string, without parsing it', () {
      final ArticleModel offset = ArticleModel.fromJson(
        buildArticleJson(url)..['publishedAt'] = '2026-10-30T11:00:00+05:30',
      );
      final ArticleModel invalid = ArticleModel.fromJson(
        buildArticleJson(url)..['publishedAt'] = 'yesterday',
      );

      expect(offset.publishedAt, '2026-10-30T11:00:00+05:30');
      expect(invalid.publishedAt, 'yesterday');
    });

    test('throws CheckedFromJsonException naming "title" when it is not a '
        'String', () {
      expect(
        () => ArticleModel.fromJson(buildArticleJson(url)..['title'] = 42),
        throwsCheckedFor(key: 'title', className: 'ArticleModel'),
      );
    });

    test('throws CheckedFromJsonException naming "source" when it is not '
        'an object', () {
      expect(
        () => ArticleModel.fromJson(buildArticleJson(url)..['source'] = 'x'),
        throwsCheckedFor(key: 'source', className: 'ArticleModel'),
      );
    });

    test('passes on the nested exception when a source field has the wrong '
        'type', () {
      expect(
        () => ArticleModel.fromJson(
          buildArticleJson(url)
            ..['source'] = <String, Object?>{'id': null, 'name': 42},
        ),
        throwsCheckedFor(key: 'name', className: 'ArticleSourceModel'),
      );
    });
  });

  group('ArticleModel equality', () {
    test('props follow the API field order', () {
      final ArticleModel model = ArticleModel.fromJson(buildArticleJson(url));

      expect(model.props, <Object?>[
        const ArticleSourceModel(
          id: 'Source id of $url',
          name: 'Source of $url',
        ),
        'Author of $url',
        'Title of $url',
        'Description of $url',
        url,
        '$url/image.jpg',
        builtArticlePublishedAtJson,
        'Content of $url',
      ]);
    });

    test('models with different URLs are not equal', () {
      final ArticleModel first = ArticleModel.fromJson(buildArticleJson(url));
      final ArticleModel second = ArticleModel.fromJson(
        buildArticleJson('https://example.com/news/b'),
      );

      expect(first, isNot(second));
    });
  });
}
