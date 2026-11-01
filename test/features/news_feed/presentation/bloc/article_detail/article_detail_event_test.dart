// Events with no fields have `const` constructors. Equality tests build them
// without `const` on purpose: identical const instances would
// pass even without `Equatable`.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';

/// Exhaustive switch with no default branch: adding an event
/// subtype breaks compilation here until the test handles it.
String describe(ArticleDetailEvent event) => switch (event) {
  ArticleDetailStarted() => 'started',
  ArticleDetailBookmarkToggled() => 'bookmark toggled',
};

void main() {
  test('ArticleDetailStarted equals another instance and has no props', () {
    final ArticleDetailStarted a = ArticleDetailStarted();
    final ArticleDetailStarted b = ArticleDetailStarted();

    expect(a, isNot(same(b)));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.props, <Object?>[]);
  });

  test(
    'ArticleDetailBookmarkToggled equals another instance and has no props',
    () {
      final ArticleDetailBookmarkToggled a = ArticleDetailBookmarkToggled();
      final ArticleDetailBookmarkToggled b = ArticleDetailBookmarkToggled();

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.props, <Object?>[]);
    },
  );

  test('different event types are not equal', () {
    expect(ArticleDetailStarted(), isNot(ArticleDetailBookmarkToggled()));
    expect(ArticleDetailBookmarkToggled(), isNot(ArticleDetailStarted()));
  });

  test('every event subtype is handled by an exhaustive switch', () {
    expect(describe(ArticleDetailStarted()), 'started');
    expect(describe(ArticleDetailBookmarkToggled()), 'bookmark toggled');
  });
}
