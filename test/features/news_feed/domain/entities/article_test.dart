import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

/// Builds an [ArticleSource] at runtime (never `const`).
ArticleSource buildSource({String? id = 'bbc-news', String name = 'BBC News'}) {
  return ArticleSource(id: id, name: name);
}

/// Builds an [Article] at runtime with overridable fields.
///
/// Passing `null` explicitly to a nullable parameter overrides its default,
/// which is how the nullability tests get their nulls.
Article buildArticle({
  String url = 'https://example.com/story',
  String title = 'Headline',
  ArticleSource? source,
  DateTime? publishedAt,
  String? author = 'Jane Doe',
  String? description = 'A short summary.',
  String? content = 'Body text… [+1234 chars]',
  String? imageUrl = 'https://example.com/image.jpg',
}) {
  return Article(
    url: url,
    title: title,
    source: source ?? buildSource(),
    publishedAt: publishedAt ?? DateTime.utc(2026, 10, 29, 12),
    author: author,
    description: description,
    content: content,
    imageUrl: imageUrl,
  );
}

void main() {
  group('Article', () {
    test('two instances with the same fields are equal', () {
      final Article a = buildArticle();
      final Article b = buildArticle();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    group('is not equal when one field differs:', () {
      test('url', () {
        expect(
          buildArticle(url: 'https://example.com/other'),
          isNot(equals(buildArticle())),
        );
      });

      test('title', () {
        expect(buildArticle(title: 'Other'), isNot(equals(buildArticle())));
      });

      test('source', () {
        expect(
          buildArticle(source: buildSource(name: 'CNN')),
          isNot(equals(buildArticle())),
        );
      });

      test('publishedAt', () {
        expect(
          buildArticle(publishedAt: DateTime.utc(2026, 10, 29, 13)),
          isNot(equals(buildArticle())),
        );
      });

      test('author', () {
        expect(buildArticle(author: 'Other'), isNot(equals(buildArticle())));
      });

      test('description', () {
        expect(
          buildArticle(description: 'Other'),
          isNot(equals(buildArticle())),
        );
      });

      test('content', () {
        expect(buildArticle(content: 'Other'), isNot(equals(buildArticle())));
      });

      test('imageUrl', () {
        expect(
          buildArticle(imageUrl: 'https://example.com/other.jpg'),
          isNot(equals(buildArticle())),
        );
      });
    });

    test('author, description, content and imageUrl may all be null', () {
      final Article article = buildArticle(
        author: null,
        description: null,
        content: null,
        imageUrl: null,
      );

      expect(article.author, isNull);
      expect(article.description, isNull);
      expect(article.content, isNull);
      expect(article.imageUrl, isNull);
      expect(
        article,
        equals(
          buildArticle(
            author: null,
            description: null,
            content: null,
            imageUrl: null,
          ),
        ),
      );
    });

    test('a null optional field is not equal to a non-null one', () {
      expect(buildArticle(imageUrl: null), isNot(equals(buildArticle())));
    });

    test('the same instant in local time and UTC is not equal (D11: the '
        'mapper must normalise publishedAt to UTC)', () {
      final DateTime utc = DateTime.utc(2026, 10, 29, 12);
      final DateTime local = utc.toLocal();

      expect(local.isAtSameMomentAs(utc), isTrue);
      expect(
        buildArticle(publishedAt: local),
        isNot(equals(buildArticle(publishedAt: utc))),
      );
    });

    test('compares the nested source by value, not identity', () {
      final ArticleSource first = buildSource();
      final ArticleSource second = buildSource();

      expect(identical(first, second), isFalse);
      expect(buildArticle(source: first), equals(buildArticle(source: second)));
    });

    test('props lists every field in declaration order', () {
      final ArticleSource source = buildSource();
      final DateTime publishedAt = DateTime.utc(2026, 10, 29, 12);

      expect(
        buildArticle(source: source, publishedAt: publishedAt).props,
        <Object?>[
          'https://example.com/story',
          'Headline',
          source,
          publishedAt,
          'Jane Doe',
          'A short summary.',
          'Body text… [+1234 chars]',
          'https://example.com/image.jpg',
        ],
      );
    });
  });
}
