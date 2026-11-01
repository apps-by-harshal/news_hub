import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

/// Builds an [ArticleSource] at runtime (never `const`), so equality tests
/// prove `Equatable` is doing the work rather than const canonicalisation.
ArticleSource buildSource({String? id = 'bbc-news', String name = 'BBC News'}) {
  return ArticleSource(id: id, name: name);
}

void main() {
  group('ArticleSource', () {
    test('two instances with the same fields are equal', () {
      final ArticleSource a = buildSource();
      final ArticleSource b = buildSource();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances with a different id are not equal', () {
      expect(buildSource(id: 'cnn'), isNot(equals(buildSource())));
    });

    test('instances with a different name are not equal', () {
      expect(buildSource(name: 'CNN'), isNot(equals(buildSource())));
    });

    test('id may be null (NewsAPI often omits it)', () {
      final ArticleSource source = buildSource(id: null);

      expect(source.id, isNull);
      expect(source.name, 'BBC News');
    });

    test('a null id is not equal to a non-null id', () {
      expect(buildSource(id: null), isNot(equals(buildSource())));
    });

    test('two sources with a null id and the same name are equal', () {
      expect(buildSource(id: null), equals(buildSource(id: null)));
    });

    test('props lists id then name', () {
      expect(buildSource().props, <Object?>['bbc-news', 'BBC News']);
    });
  });
}
