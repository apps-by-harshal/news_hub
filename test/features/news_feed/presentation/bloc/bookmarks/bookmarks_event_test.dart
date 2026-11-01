// Events have no fields, so every instance below is built without `const` on
// purpose: identical const instances would pass without Equatable
// (agreement 9).
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_event.dart';

/// No default branch: adding an event breaks compilation here until the test
/// (and the bloc) handle it.
String _describe(BookmarksEvent event) {
  return switch (event) {
    BookmarksStarted() => 'started',
    BookmarksRefreshed() => 'refreshed',
  };
}

void main() {
  group('BookmarksStarted', () {
    test('instances are equal, with the same hashCode and no props', () {
      final BookmarksEvent first = BookmarksStarted();
      final BookmarksEvent second = BookmarksStarted();

      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
      expect(first.props, isEmpty);
    });
  });

  group('BookmarksRefreshed', () {
    test('instances are equal, with the same hashCode and no props', () {
      final BookmarksEvent first = BookmarksRefreshed();
      final BookmarksEvent second = BookmarksRefreshed();

      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
      expect(first.props, isEmpty);
    });
  });

  group('BookmarksEvent', () {
    test('different event types are not equal', () {
      expect(BookmarksStarted(), isNot(equals(BookmarksRefreshed())));
    });

    test('a switch over the sealed family is exhaustive', () {
      expect(_describe(BookmarksStarted()), 'started');
      expect(_describe(BookmarksRefreshed()), 'refreshed');
    });
  });
}
