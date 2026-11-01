import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

/// Builds an article whose every field is derived from [url], so no
/// constructor call has only literal arguments (agreement 9).
Article buildArticle(String url) => Article(
  url: url,
  title: 'Title for $url',
  source: ArticleSource(id: null, name: 'Source for $url'),
  publishedAt: DateTime.utc(2026, 10, 30),
  author: null,
  description: null,
  content: null,
  imageUrl: null,
);

/// Builds a page at runtime (never `const`, agreement 9).
RemoteArticlesPage buildPage({
  List<String> urls = const <String>[
    'https://example.com/a',
    'https://example.com/b',
  ],
  int totalResults = 42,
}) => RemoteArticlesPage(
  articles: urls.map(buildArticle).toList(),
  totalResults: totalResults,
);

void main() {
  group('RemoteArticlesPage', () {
    test(
      'is equal (with equal hashCode) when articles and totalResults match',
      () {
        final RemoteArticlesPage a = buildPage();
        final RemoteArticlesPage b = buildPage();

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('is not equal when article contents differ', () {
      final RemoteArticlesPage a = buildPage(
        urls: <String>['https://example.com/a', 'https://example.com/b'],
      );
      final RemoteArticlesPage b = buildPage(
        urls: <String>['https://example.com/a', 'https://example.com/c'],
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when article order differs', () {
      final RemoteArticlesPage a = buildPage(
        urls: <String>['https://example.com/a', 'https://example.com/b'],
      );
      final RemoteArticlesPage b = buildPage(
        urls: <String>['https://example.com/b', 'https://example.com/a'],
      );

      expect(a, isNot(equals(b)));
    });

    test('is not equal when totalResults differs', () {
      final RemoteArticlesPage a = buildPage(totalResults: 42);
      final RemoteArticlesPage b = buildPage(totalResults: 43);

      expect(a, isNot(equals(b)));
    });

    test('articles cannot be modified', () {
      final RemoteArticlesPage page = buildPage();

      expect(
        () => page.articles.add(buildArticle('https://example.com/z')),
        throwsUnsupportedError,
      );
    });

    test('keeps a defensive copy of the source list', () {
      final List<Article> source = <Article>[
        buildArticle('https://example.com/a'),
      ];
      final RemoteArticlesPage page = RemoteArticlesPage(
        articles: source,
        totalResults: 1,
      );

      source.add(buildArticle('https://example.com/b'));

      expect(page.articles, hasLength(1));
      expect(page.articles.single.url, equals('https://example.com/a'));
    });

    test('accepts totalResults 0 with no articles; negative throws '
        'AssertionError', () {
      final RemoteArticlesPage empty = RemoteArticlesPage(
        articles: const <Article>[],
        totalResults: 0,
      );

      expect(empty.articles, isEmpty);
      expect(empty.totalResults, equals(0));
      expect(
        () => RemoteArticlesPage(articles: const <Article>[], totalResults: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('props are [articles, totalResults] in that order', () {
      final RemoteArticlesPage page = buildPage(totalResults: 42);

      expect(page.props, equals(<Object?>[page.articles, 42]));
    });
  });
}
