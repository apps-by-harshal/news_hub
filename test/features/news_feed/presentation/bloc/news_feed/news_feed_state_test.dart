// States are built without `const` on purpose (agreement 9): identical const
// instances would pass equality tests even without `Equatable`.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_state.dart';

/// An article whose fields all derive from [url], so two calls with the same
/// URL build equal (but not identical) articles.
Article buildStateArticle(String url) => Article(
  url: url,
  title: 'Title for $url',
  source: ArticleSource(id: null, name: 'Source for $url'),
  publishedAt: DateTime.utc(2026, 10, 31, 12),
  author: null,
  description: null,
  content: null,
  imageUrl: null,
);

const String urlA = 'https://example.com/a';
const String urlB = 'https://example.com/b';
const String urlC = 'https://example.com/c';

/// A loaded state with every field given, built fresh on each call.
NewsFeedLoaded buildLoaded({
  NewsCategory category = NewsCategory.general,
  List<Article>? articles,
  int page = 1,
  bool hasMore = true,
  bool isOffline = false,
  bool isLoadingMore = false,
  bool isRefreshing = false,
  failures.Failure? loadMoreFailure,
  failures.Failure? refreshFailure,
}) => NewsFeedLoaded(
  category: category,
  articles:
      articles ?? <Article>[buildStateArticle(urlA), buildStateArticle(urlB)],
  page: page,
  hasMore: hasMore,
  isOffline: isOffline,
  isLoadingMore: isLoadingMore,
  isRefreshing: isRefreshing,
  loadMoreFailure: loadMoreFailure,
  refreshFailure: refreshFailure,
);

/// Exhaustive switch with no default branch (agreement 10): adding a state
/// subtype breaks compilation here until the test handles it.
String describe(NewsFeedState state) => switch (state) {
  NewsFeedInitial(:final NewsCategory category) => 'initial ${category.name}',
  NewsFeedLoading(:final NewsCategory category) => 'loading ${category.name}',
  NewsFeedLoaded(:final NewsCategory category, :final List<Article> articles) =>
    'loaded ${category.name} ${articles.length}',
  NewsFeedFailure(:final NewsCategory category) => 'failure ${category.name}',
};

void main() {
  const failures.Failure networkFailure = failures.NetworkFailure('offline');
  const failures.Failure serverFailure = failures.ServerFailure(
    'boom',
    statusCode: 500,
  );

  group('NewsFeedInitial', () {
    test('uses the default category, general', () {
      final NewsFeedInitial state = NewsFeedInitial();

      expect(state.category, NewsCategory.general);
      expect(state.props, <Object?>[NewsCategory.general]);
    });

    test('equals another instance', () {
      final NewsFeedInitial a = NewsFeedInitial();
      final NewsFeedInitial b = NewsFeedInitial();

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('NewsFeedLoading', () {
    test('equal for the same category, not for a different one', () {
      const NewsCategory sports = NewsCategory.sports;
      const NewsCategory science = NewsCategory.science;

      expect(
        NewsFeedLoading(category: sports),
        NewsFeedLoading(category: sports),
      );
      expect(
        NewsFeedLoading(category: sports).hashCode,
        NewsFeedLoading(category: sports).hashCode,
      );
      expect(
        NewsFeedLoading(category: sports),
        isNot(NewsFeedLoading(category: science)),
      );
    });

    test('keeps the category and exposes it as the only prop', () {
      const NewsCategory health = NewsCategory.health;
      final NewsFeedLoading state = NewsFeedLoading(category: health);

      expect(state.category, NewsCategory.health);
      expect(state.props, <Object?>[NewsCategory.health]);
    });

    test('is not equal to NewsFeedInitial with the same category', () {
      const NewsCategory general = NewsCategory.general;

      expect(NewsFeedLoading(category: general), isNot(NewsFeedInitial()));
    });
  });

  group('NewsFeedLoaded', () {
    test('transient fields default to idle with no failures', () {
      final NewsFeedLoaded state = NewsFeedLoaded(
        category: NewsCategory.business,
        articles: <Article>[buildStateArticle(urlA)],
        page: 1,
        hasMore: true,
        isOffline: false,
      );

      expect(state.isLoadingMore, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.loadMoreFailure, isNull);
      expect(state.refreshFailure, isNull);
    });

    test('equal when every field is equal', () {
      final NewsFeedLoaded a = buildLoaded(
        loadMoreFailure: networkFailure,
        refreshFailure: serverFailure,
      );
      final NewsFeedLoaded b = buildLoaded(
        loadMoreFailure: networkFailure,
        refreshFailure: serverFailure,
      );

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when any one field differs', () {
      final NewsFeedLoaded base = buildLoaded();
      final Map<String, NewsFeedLoaded> variants = <String, NewsFeedLoaded>{
        'category': buildLoaded(category: NewsCategory.technology),
        'articles (different item)': buildLoaded(
          articles: <Article>[buildStateArticle(urlA), buildStateArticle(urlC)],
        ),
        'articles (order)': buildLoaded(
          articles: <Article>[buildStateArticle(urlB), buildStateArticle(urlA)],
        ),
        'articles (count)': buildLoaded(
          articles: <Article>[buildStateArticle(urlA)],
        ),
        'page': buildLoaded(page: 2),
        'hasMore': buildLoaded(hasMore: false),
        'isOffline': buildLoaded(isOffline: true),
        'isLoadingMore': buildLoaded(isLoadingMore: true),
        'isRefreshing': buildLoaded(isRefreshing: true),
        'loadMoreFailure': buildLoaded(loadMoreFailure: networkFailure),
        'refreshFailure': buildLoaded(refreshFailure: networkFailure),
      };

      for (final MapEntry<String, NewsFeedLoaded> entry in variants.entries) {
        expect(entry.value, isNot(base), reason: entry.key);
      }
    });

    test('props list every field in declaration order', () {
      final List<Article> articles = <Article>[buildStateArticle(urlA)];
      final NewsFeedLoaded state = buildLoaded(
        category: NewsCategory.entertainment,
        articles: articles,
        page: 3,
        hasMore: false,
        isOffline: true,
        isLoadingMore: true,
        isRefreshing: true,
        loadMoreFailure: networkFailure,
        refreshFailure: serverFailure,
      );

      expect(state.props, <Object?>[
        NewsCategory.entertainment,
        articles,
        3,
        false,
        true,
        true,
        true,
        networkFailure,
        serverFailure,
      ]);
    });

    test('articles are unmodifiable', () {
      final NewsFeedLoaded state = buildLoaded();

      expect(
        () => state.articles.add(buildStateArticle(urlC)),
        throwsUnsupportedError,
      );
    });

    test('articles are copied, so later changes to the source list do not '
        'leak in', () {
      final List<Article> source = <Article>[buildStateArticle(urlA)];
      final NewsFeedLoaded state = buildLoaded(articles: source);

      source.add(buildStateArticle(urlB));

      expect(state.articles, <Article>[buildStateArticle(urlA)]);
    });

    test('page below 1 fails the assert', () {
      expect(() => buildLoaded(page: 0), throwsA(isA<AssertionError>()));
    });
  });

  group('NewsFeedLoaded.copyWith', () {
    test('with no arguments returns an equal, separate state', () {
      final NewsFeedLoaded original = buildLoaded(
        page: 2,
        isOffline: true,
        loadMoreFailure: networkFailure,
        refreshFailure: serverFailure,
      );

      final NewsFeedLoaded copy = original.copyWith();

      expect(copy, isNot(same(original)));
      expect(copy, original);
    });

    test('replaces each non-failure field it is given and keeps the '
        'category', () {
      final NewsFeedLoaded original = buildLoaded(
        category: NewsCategory.sports,
      );
      final List<Article> articles = <Article>[buildStateArticle(urlC)];

      final NewsFeedLoaded copy = original.copyWith(
        articles: articles,
        page: 4,
        hasMore: false,
        isOffline: true,
        isLoadingMore: true,
        isRefreshing: true,
      );

      expect(
        copy,
        buildLoaded(
          category: NewsCategory.sports,
          articles: <Article>[buildStateArticle(urlC)],
          page: 4,
          hasMore: false,
          isOffline: true,
          isLoadingMore: true,
          isRefreshing: true,
        ),
      );
    });

    test('sets the failures through callbacks and keeps them when '
        'omitted', () {
      final NewsFeedLoaded withFailures = buildLoaded().copyWith(
        loadMoreFailure: () => networkFailure,
        refreshFailure: () => serverFailure,
      );

      expect(withFailures.loadMoreFailure, networkFailure);
      expect(withFailures.refreshFailure, serverFailure);

      final NewsFeedLoaded kept = withFailures.copyWith(page: 2);

      expect(kept.loadMoreFailure, networkFailure);
      expect(kept.refreshFailure, serverFailure);
    });

    test('clears a failure with a callback returning null', () {
      final NewsFeedLoaded original = buildLoaded(
        loadMoreFailure: networkFailure,
        refreshFailure: serverFailure,
      );

      final NewsFeedLoaded cleared = original.copyWith(
        loadMoreFailure: () => null,
        refreshFailure: () => null,
      );

      expect(cleared.loadMoreFailure, isNull);
      expect(cleared.refreshFailure, isNull);
      expect(cleared, buildLoaded());
    });

    test('keeps the articles unmodifiable', () {
      final NewsFeedLoaded copy = buildLoaded().copyWith(
        articles: <Article>[buildStateArticle(urlC)],
      );

      expect(
        () => copy.articles.add(buildStateArticle(urlA)),
        throwsUnsupportedError,
      );
    });
  });

  group('NewsFeedFailure', () {
    test('equal for the same category and failure', () {
      const NewsCategory general = NewsCategory.general;
      final NewsFeedFailure a = NewsFeedFailure(
        category: general,
        failure: networkFailure,
      );
      final NewsFeedFailure b = NewsFeedFailure(
        category: general,
        failure: networkFailure,
      );

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal for a different category or failure', () {
      const NewsCategory general = NewsCategory.general;
      const NewsCategory sports = NewsCategory.sports;
      final NewsFeedFailure base = NewsFeedFailure(
        category: general,
        failure: networkFailure,
      );

      expect(
        NewsFeedFailure(category: sports, failure: networkFailure),
        isNot(base),
      );
      expect(
        NewsFeedFailure(category: general, failure: serverFailure),
        isNot(base),
      );
    });

    test('keeps category and failure as props, in that order', () {
      const NewsCategory science = NewsCategory.science;
      final NewsFeedFailure state = NewsFeedFailure(
        category: science,
        failure: serverFailure,
      );

      expect(state.category, NewsCategory.science);
      expect(state.failure, serverFailure);
      expect(state.props, <Object?>[NewsCategory.science, serverFailure]);
    });
  });

  test('every state subtype is handled by an exhaustive switch', () {
    const NewsCategory health = NewsCategory.health;

    expect(describe(NewsFeedInitial()), 'initial general');
    expect(describe(NewsFeedLoading(category: health)), 'loading health');
    expect(
      describe(buildLoaded(category: NewsCategory.health)),
      'loaded health 2',
    );
    expect(
      describe(NewsFeedFailure(category: health, failure: networkFailure)),
      'failure health',
    );
  });
}
