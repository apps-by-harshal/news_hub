// Events with no fields have `const` constructors. Equality tests build them
// without `const` on purpose (agreement 9): identical const instances would
// pass even without `Equatable`.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_event.dart';

/// Exhaustive switch with no default branch (agreement 10): adding an event
/// subtype breaks compilation here until the test handles it.
String describe(NewsFeedEvent event) => switch (event) {
  NewsFeedStarted() => 'started',
  NewsFeedRefreshed() => 'refreshed',
  NewsFeedNextPageRequested() => 'next page',
  NewsFeedCategoryChanged(:final NewsCategory category) =>
    'category ${category.name}',
};

void main() {
  group('events without fields', () {
    test('NewsFeedStarted equals another instance and has no props', () {
      final NewsFeedStarted a = NewsFeedStarted();
      final NewsFeedStarted b = NewsFeedStarted();

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.props, <Object?>[]);
    });

    test('NewsFeedRefreshed equals another instance and has no props', () {
      final NewsFeedRefreshed a = NewsFeedRefreshed();
      final NewsFeedRefreshed b = NewsFeedRefreshed();

      expect(a, isNot(same(b)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.props, <Object?>[]);
    });

    test(
      'NewsFeedNextPageRequested equals another instance and has no props',
      () {
        final NewsFeedNextPageRequested a = NewsFeedNextPageRequested();
        final NewsFeedNextPageRequested b = NewsFeedNextPageRequested();

        expect(a, isNot(same(b)));
        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a.props, <Object?>[]);
      },
    );

    test('different event types are not equal', () {
      final List<NewsFeedEvent> events = <NewsFeedEvent>[
        NewsFeedStarted(),
        NewsFeedRefreshed(),
        NewsFeedNextPageRequested(),
      ];

      for (int i = 0; i < events.length; i++) {
        for (int j = 0; j < events.length; j++) {
          if (i != j) {
            expect(events[i], isNot(events[j]));
          }
        }
      }
    });
  });

  group('NewsFeedCategoryChanged', () {
    test('equal for the same category, for every category', () {
      for (final NewsCategory category in NewsCategory.values) {
        final NewsFeedCategoryChanged a = NewsFeedCategoryChanged(category);
        final NewsFeedCategoryChanged b = NewsFeedCategoryChanged(category);

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      }
    });

    test('not equal for different categories', () {
      const NewsCategory first = NewsCategory.general;
      const NewsCategory second = NewsCategory.technology;

      expect(
        NewsFeedCategoryChanged(first),
        isNot(NewsFeedCategoryChanged(second)),
      );
    });

    test('keeps the category and exposes it as the only prop', () {
      const NewsCategory category = NewsCategory.sports;
      final NewsFeedCategoryChanged event = NewsFeedCategoryChanged(category);

      expect(event.category, NewsCategory.sports);
      expect(event.props, <Object?>[NewsCategory.sports]);
    });
  });

  test('every event subtype is handled by an exhaustive switch', () {
    const NewsCategory category = NewsCategory.health;

    expect(describe(NewsFeedStarted()), 'started');
    expect(describe(NewsFeedRefreshed()), 'refreshed');
    expect(describe(NewsFeedNextPageRequested()), 'next page');
    expect(describe(NewsFeedCategoryChanged(category)), 'category health');
  });
}
