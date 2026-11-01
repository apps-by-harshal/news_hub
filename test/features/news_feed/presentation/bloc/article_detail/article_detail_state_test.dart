import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_state.dart';

import '../../../../../fixtures/article_builders.dart';

// States are built at runtime from `buildArticle(url)`, never as `const`
// (agreement 9).

const String urlA = 'https://example.com/a';
const String urlB = 'https://example.com/b';

const failures.Failure cacheFailure = failures.CacheFailure('disk');
const failures.Failure unexpectedFailure = failures.UnexpectedFailure('bug');

/// Exhaustive switch with no default branch (agreement 10): adding a state
/// subtype breaks compilation here until the test handles it.
String describe(ArticleDetailState state) => switch (state) {
  ArticleDetailLoading() => 'loading',
  ArticleDetailReady(:final bool isBookmarked) => 'ready $isBookmarked',
  ArticleDetailStatusFailure() => 'status failure',
};

void main() {
  group('ArticleDetailLoading', () {
    test('keeps the article and exposes it as the only prop', () {
      final Article article = buildArticle(urlA);
      final ArticleDetailLoading state = ArticleDetailLoading(article: article);

      expect(state.article, buildArticle(urlA));
      expect(state.props, <Object?>[buildArticle(urlA)]);
    });

    test('equal for the same article, not for a different one', () {
      final ArticleDetailLoading a = ArticleDetailLoading(
        article: buildArticle(urlA),
      );
      final ArticleDetailLoading b = ArticleDetailLoading(
        article: buildArticle(urlA),
      );

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(ArticleDetailLoading(article: buildArticle(urlB))));
    });

    test('is not equal to the other states for the same article', () {
      final ArticleDetailLoading loading = ArticleDetailLoading(
        article: buildArticle(urlA),
      );

      expect(
        loading,
        isNot(
          ArticleDetailReady(article: buildArticle(urlA), isBookmarked: false),
        ),
      );
      expect(
        loading,
        isNot(
          ArticleDetailStatusFailure(
            article: buildArticle(urlA),
            failure: cacheFailure,
          ),
        ),
      );
    });
  });

  group('ArticleDetailReady', () {
    test('defaults to not toggling, with no failure', () {
      final ArticleDetailReady state = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: true,
      );

      expect(state.isBookmarked, isTrue);
      expect(state.isToggling, isFalse);
      expect(state.toggleFailure, isNull);
    });

    test('equal when every field is equal', () {
      final ArticleDetailReady a = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: true,
        isToggling: true,
        toggleFailure: cacheFailure,
      );
      final ArticleDetailReady b = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: true,
        isToggling: true,
        toggleFailure: cacheFailure,
      );

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal when any one field differs', () {
      final ArticleDetailReady base = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: false,
      );
      final Map<String, ArticleDetailReady> variants =
          <String, ArticleDetailReady>{
            'article (other URL)': ArticleDetailReady(
              article: buildArticle(urlB),
              isBookmarked: false,
            ),
            'article (same URL, other fields)': ArticleDetailReady(
              article: buildArticleWithoutOptionals(urlA),
              isBookmarked: false,
            ),
            'isBookmarked': ArticleDetailReady(
              article: buildArticle(urlA),
              isBookmarked: true,
            ),
            'isToggling': ArticleDetailReady(
              article: buildArticle(urlA),
              isBookmarked: false,
              isToggling: true,
            ),
            'toggleFailure': ArticleDetailReady(
              article: buildArticle(urlA),
              isBookmarked: false,
              toggleFailure: cacheFailure,
            ),
          };

      for (final MapEntry<String, ArticleDetailReady> entry
          in variants.entries) {
        expect(entry.value, isNot(base), reason: entry.key);
      }
    });

    test('props list every field in declaration order', () {
      final ArticleDetailReady state = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: true,
        isToggling: true,
        toggleFailure: unexpectedFailure,
      );

      expect(state.props, <Object?>[
        buildArticle(urlA),
        true,
        true,
        unexpectedFailure,
      ]);
    });
  });

  group('ArticleDetailReady.copyWith', () {
    test('with no arguments returns an equal, separate state', () {
      final ArticleDetailReady original = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: true,
        isToggling: true,
        toggleFailure: cacheFailure,
      );

      final ArticleDetailReady copy = original.copyWith();

      expect(copy, isNot(same(original)));
      expect(copy, original);
    });

    test('replaces isBookmarked and isToggling and keeps the article', () {
      final ArticleDetailReady original = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: false,
      );

      final ArticleDetailReady copy = original.copyWith(
        isBookmarked: true,
        isToggling: true,
      );

      expect(
        copy,
        ArticleDetailReady(
          article: buildArticle(urlA),
          isBookmarked: true,
          isToggling: true,
        ),
      );
    });

    test('sets the failure through a callback and keeps it when omitted', () {
      final ArticleDetailReady withFailure = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: false,
      ).copyWith(toggleFailure: () => cacheFailure);

      expect(withFailure.toggleFailure, cacheFailure);
      expect(
        withFailure.copyWith(isToggling: true).toggleFailure,
        cacheFailure,
      );
    });

    test('clears the failure with a callback returning null', () {
      final ArticleDetailReady cleared = ArticleDetailReady(
        article: buildArticle(urlA),
        isBookmarked: true,
        toggleFailure: cacheFailure,
      ).copyWith(toggleFailure: () => null);

      expect(cleared.toggleFailure, isNull);
      expect(
        cleared,
        ArticleDetailReady(article: buildArticle(urlA), isBookmarked: true),
      );
    });
  });

  group('ArticleDetailStatusFailure', () {
    test('equal for the same article and failure', () {
      final ArticleDetailStatusFailure a = ArticleDetailStatusFailure(
        article: buildArticle(urlA),
        failure: cacheFailure,
      );
      final ArticleDetailStatusFailure b = ArticleDetailStatusFailure(
        article: buildArticle(urlA),
        failure: cacheFailure,
      );

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('not equal for a different article or failure', () {
      final ArticleDetailStatusFailure base = ArticleDetailStatusFailure(
        article: buildArticle(urlA),
        failure: cacheFailure,
      );

      expect(
        ArticleDetailStatusFailure(
          article: buildArticle(urlB),
          failure: cacheFailure,
        ),
        isNot(base),
      );
      expect(
        ArticleDetailStatusFailure(
          article: buildArticle(urlA),
          failure: unexpectedFailure,
        ),
        isNot(base),
      );
    });

    test('keeps article and failure as props, in that order', () {
      final ArticleDetailStatusFailure state = ArticleDetailStatusFailure(
        article: buildArticle(urlA),
        failure: unexpectedFailure,
      );

      expect(state.article, buildArticle(urlA));
      expect(state.failure, unexpectedFailure);
      expect(state.props, <Object?>[buildArticle(urlA), unexpectedFailure]);
    });
  });

  test('every state subtype is handled by an exhaustive switch', () {
    final Article article = buildArticle(urlA);

    expect(describe(ArticleDetailLoading(article: article)), 'loading');
    expect(
      describe(ArticleDetailReady(article: article, isBookmarked: true)),
      'ready true',
    );
    expect(
      describe(
        ArticleDetailStatusFailure(article: article, failure: cacheFailure),
      ),
      'status failure',
    );
  });
}
