import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/data/models/article_model.dart';
import 'package:news_hub/features/news_feed/data/models/article_source_model.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';

import '../../../../fixtures/fixture_reader.dart';
import '../../../../helpers/json_matchers.dart';

void main() {
  group('NewsResponseModel.fromJson with fixtures', () {
    test('reads status, totalResults and all 6 articles in order', () {
      final NewsResponseModel model = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json'),
      );

      expect(model.status, 'ok');
      expect(model.totalResults, 38);
      expect(model.articles?.map((ArticleModel a) => a.url).toList(), <String?>[
        'https://example.com/news/markets-rally',
        'https://techdaily.example.org/2026/10/folding-phone',
        'https://removed.com',
        'https://healthwire.example.net/untitled',
        'https://indiatimes.example.in/politics/session-opens',
        'https://sportscentral.example.com/final-draw',
      ]);
    });

    test('reads a complete article with its nested source', () {
      final NewsResponseModel model = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json'),
      );

      expect(
        model.articles?.first,
        const ArticleModel(
          source: ArticleSourceModel(id: 'example-news', name: 'Example News'),
          author: 'Jane Doe',
          title: 'Markets rally as inflation cools',
          description:
              'Stocks rose for a third day after new figures showed prices '
              'easing.',
          url: 'https://example.com/news/markets-rally',
          urlToImage: 'https://example.com/images/markets-rally.jpg',
          publishedAt: '2026-10-30T08:30:00Z',
          content: 'Stocks rose for a third straight day on Thursday.',
        ),
      );
    });

    test('reads an article whose optional fields are null', () {
      final NewsResponseModel model = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json'),
      );

      expect(
        model.articles?[1],
        const ArticleModel(
          source: ArticleSourceModel(id: null, name: 'Tech Daily'),
          author: null,
          title: 'New folding phone announced',
          description: null,
          url: 'https://techdaily.example.org/2026/10/folding-phone',
          urlToImage: null,
          publishedAt: '2026-10-30T07:15:00Z',
          content: null,
        ),
      );
    });

    test('reads the empty response as an empty list, not null', () {
      final NewsResponseModel model = NewsResponseModel.fromJson(
        fixtureJson('empty_response.json'),
      );

      expect(model.status, 'ok');
      expect(model.totalResults, 0);
      expect(model.articles, isNotNull);
      expect(model.articles, isEmpty);
    });

    test('reads the error envelope without throwing', () {
      final NewsResponseModel model = NewsResponseModel.fromJson(
        fixtureJson('error_response.json'),
      );

      expect(
        model,
        const NewsResponseModel(
          status: 'error',
          totalResults: null,
          articles: null,
        ),
      );
    });
  });

  group('NewsResponseModel.fromJson with wrong types', () {
    test('throws for "articles" when it is not a list', () {
      expect(
        () => NewsResponseModel.fromJson(<String, Object?>{
          'status': 'ok',
          'totalResults': 1,
          'articles': 'x',
        }),
        throwsCheckedFor(key: 'articles', className: 'NewsResponseModel'),
      );
    });

    test('throws for "articles" when an element is not an object', () {
      expect(
        () => NewsResponseModel.fromJson(<String, Object?>{
          'status': 'ok',
          'totalResults': 1,
          'articles': <Object?>['x'],
        }),
        throwsCheckedFor(key: 'articles', className: 'NewsResponseModel'),
      );
    });

    test('passes on the nested exception when an article field has the '
        'wrong type', () {
      expect(
        () => NewsResponseModel.fromJson(<String, Object?>{
          'status': 'ok',
          'totalResults': 1,
          'articles': <Object?>[
            <String, Object?>{'title': 42},
          ],
        }),
        throwsCheckedFor(key: 'title', className: 'ArticleModel'),
      );
    });

    test('throws for "totalResults" when it is not a number', () {
      expect(
        () => NewsResponseModel.fromJson(<String, Object?>{
          'status': 'ok',
          'totalResults': '38',
          'articles': <Object?>[],
        }),
        throwsCheckedFor(key: 'totalResults', className: 'NewsResponseModel'),
      );
    });
  });

  group('NewsResponseModel equality', () {
    test('props are [status, totalResults, articles]', () {
      final NewsResponseModel model = NewsResponseModel.fromJson(
        fixtureJson('empty_response.json'),
      );

      expect(model.props, <Object?>['ok', 0, <ArticleModel>[]]);
    });

    test('two parses of the same fixture are equal, article by article', () {
      final NewsResponseModel first = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json'),
      );
      final NewsResponseModel second = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json'),
      );

      expect(first, second);
    });

    test('responses with different articles are not equal', () {
      final Map<String, Object?> json = fixtureJson(
        'top_headlines_response.json',
      );
      final List<Object?> articles = json['articles'] as List<Object?>;

      final NewsResponseModel full = NewsResponseModel.fromJson(json);
      final NewsResponseModel shortened = NewsResponseModel.fromJson(
        fixtureJson('top_headlines_response.json')
          ..['articles'] = articles.sublist(0, 5),
      );

      expect(full, isNot(shortened));
    });
  });
}
