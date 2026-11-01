// States under test are built without `const` on purpose: identical const
// instances would pass without Equatable. `BookmarksLoading`
// has no fields and `BookmarksFailure` takes a const failure, so the lint
// would ask for `const` on them.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_state.dart';

import '../../../../../fixtures/article_builders.dart';

const String _urlA = 'https://example.com/bookmarks/a';
const String _urlB = 'https://example.com/bookmarks/b';

const failures.Failure _cacheFailure = failures.CacheFailure('box closed');
const failures.Failure _unexpectedFailure = failures.UnexpectedFailure('boom');

/// Builds a fresh list on every call, so two states never share one list.
List<Article> _articles(List<String> urls) => urls.map(buildArticle).toList();

/// No default branch: adding a state breaks compilation here until the test
/// (and the view) handle it.
String _describe(BookmarksState state) {
  return switch (state) {
    BookmarksLoading() => 'loading',
    BookmarksLoaded() => 'loaded',
    BookmarksFailure() => 'failure',
  };
}

void main() {
  group('BookmarksLoading', () {
    test('instances are equal, with the same hashCode and no props', () {
      final BookmarksState first = BookmarksLoading();
      final BookmarksState second = BookmarksLoading();

      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
      expect(first.props, isEmpty);
    });
  });

  group('BookmarksLoaded', () {
    test('has no refresh failure by default', () {
      final BookmarksLoaded state = BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
      );

      expect(state.refreshFailure, isNull);
    });

    test('is equal for the same articles in different lists', () {
      final BookmarksLoaded first = BookmarksLoaded(
        articles: _articles(<String>[_urlA, _urlB]),
      );
      final BookmarksLoaded second = BookmarksLoaded(
        articles: _articles(<String>[_urlA, _urlB]),
      );

      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
    });

    test('is not equal for different articles', () {
      expect(
        BookmarksLoaded(articles: _articles(<String>[_urlA])),
        isNot(equals(BookmarksLoaded(articles: _articles(<String>[_urlB])))),
      );
    });

    test('is not equal for the same articles in another order', () {
      expect(
        BookmarksLoaded(articles: _articles(<String>[_urlA, _urlB])),
        isNot(
          equals(BookmarksLoaded(articles: _articles(<String>[_urlB, _urlA]))),
        ),
      );
    });

    test('is not equal for a different refresh failure', () {
      final BookmarksLoaded without = BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
      );
      final BookmarksLoaded withCache = BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
        refreshFailure: _cacheFailure,
      );
      final BookmarksLoaded withUnexpected = BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
        refreshFailure: _unexpectedFailure,
      );

      expect(without, isNot(equals(withCache)));
      expect(withCache, isNot(equals(withUnexpected)));
    });

    test('props are [articles, refreshFailure]', () {
      final BookmarksLoaded state = BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
        refreshFailure: _cacheFailure,
      );

      expect(state.props, <Object?>[
        _articles(<String>[_urlA]),
        _cacheFailure,
      ]);
    });

    test('allows an empty list (nothing bookmarked)', () {
      final BookmarksLoaded state = BookmarksLoaded(
        articles: const <Article>[],
      );

      expect(state.articles, isEmpty);
    });

    test('articles cannot be modified', () {
      final BookmarksLoaded state = BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
      );

      expect(
        () => state.articles.add(buildArticle(_urlB)),
        throwsUnsupportedError,
      );
    });

    test('keeps its own copy of the articles', () {
      final List<Article> input = _articles(<String>[_urlA]);
      final BookmarksLoaded state = BookmarksLoaded(articles: input);

      input.add(buildArticle(_urlB));

      expect(state.articles, _articles(<String>[_urlA]));
    });
  });

  group('BookmarksFailure', () {
    test('is equal for the same failure', () {
      final BookmarksFailure first = BookmarksFailure(_cacheFailure);
      final BookmarksFailure second = BookmarksFailure(_cacheFailure);

      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
      expect(first.failure, _cacheFailure);
    });

    test('is not equal for a different failure', () {
      expect(
        BookmarksFailure(_cacheFailure),
        isNot(equals(BookmarksFailure(_unexpectedFailure))),
      );
    });

    test('props are [failure]', () {
      expect(BookmarksFailure(_cacheFailure).props, <Object?>[_cacheFailure]);
    });
  });

  group('BookmarksState', () {
    test('different state types are not equal', () {
      final BookmarksState loading = BookmarksLoading();
      final BookmarksState loaded = BookmarksLoaded(
        articles: const <Article>[],
      );

      expect(loading, isNot(equals(loaded)));
    });

    test('a switch over the sealed family is exhaustive', () {
      expect(_describe(BookmarksLoading()), 'loading');
      expect(_describe(BookmarksLoaded(articles: const <Article>[])), 'loaded');
      expect(_describe(BookmarksFailure(_cacheFailure)), 'failure');
    });
  });
}
