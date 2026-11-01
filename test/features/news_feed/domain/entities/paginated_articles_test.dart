import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';

/// Builds an [Article] at runtime that differs only by [url].
///
/// [sourceName] is a parameter so the nested `ArticleSource` is never
/// const-eligible (and keeps `prefer_const_constructors` quiet).
Article buildArticle(String url, {String sourceName = 'BBC News'}) {
  return Article(
    url: url,
    title: 'Headline',
    source: ArticleSource(id: null, name: sourceName),
    publishedAt: DateTime.utc(2026, 10, 29, 12),
    author: null,
    description: null,
    content: null,
    imageUrl: null,
  );
}

/// Builds a [PaginatedArticles] at runtime with overridable fields.
PaginatedArticles buildPage({
  List<Article>? items,
  int page = 1,
  bool hasMore = true,
  bool isFromCache = false,
}) {
  return PaginatedArticles(
    items:
        items ??
        <Article>[
          buildArticle('https://example.com/a'),
          buildArticle('https://example.com/b'),
        ],
    page: page,
    hasMore: hasMore,
    isFromCache: isFromCache,
  );
}

void main() {
  group('PaginatedArticles', () {
    test(
      'equal when items have equal contents in different list instances',
      () {
        final PaginatedArticles a = buildPage();
        final PaginatedArticles b = buildPage();

        expect(identical(a.items, b.items), isFalse);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('not equal when page differs', () {
      expect(buildPage(page: 2), isNot(equals(buildPage())));
    });

    test('not equal when hasMore differs', () {
      expect(buildPage(hasMore: false), isNot(equals(buildPage())));
    });

    test('not equal when isFromCache differs', () {
      expect(buildPage(isFromCache: true), isNot(equals(buildPage())));
    });

    test('not equal when item order differs', () {
      final Article a = buildArticle('https://example.com/a');
      final Article b = buildArticle('https://example.com/b');

      expect(
        buildPage(items: <Article>[b, a]),
        isNot(equals(buildPage(items: <Article>[a, b]))),
      );
    });

    test('not equal when item count differs', () {
      expect(
        buildPage(items: <Article>[buildArticle('https://example.com/a')]),
        isNot(equals(buildPage())),
      );
    });

    test('items may be empty', () {
      final PaginatedArticles empty = buildPage(
        items: <Article>[],
        hasMore: false,
      );

      expect(empty.items, isEmpty);
    });

    test('items cannot be modified', () {
      final PaginatedArticles page = buildPage();

      expect(
        () => page.items.add(buildArticle('https://example.com/c')),
        throwsUnsupportedError,
      );
    });

    test(
      "changing the caller's list afterwards does not change the entity",
      () {
        final List<Article> callerList = <Article>[
          buildArticle('https://example.com/a'),
        ];
        final PaginatedArticles page = buildPage(items: callerList);

        callerList.add(buildArticle('https://example.com/b'));

        expect(page.items, hasLength(1));
      },
    );

    test('page must be at least 1', () {
      expect(() => buildPage(page: 0), throwsA(isA<AssertionError>()));
    });

    test('props lists items, page, hasMore, then isFromCache', () {
      final PaginatedArticles page = buildPage(
        page: 3,
        hasMore: false,
        isFromCache: true,
      );

      expect(page.props, <Object?>[page.items, 3, false, true]);
    });
  });
}
