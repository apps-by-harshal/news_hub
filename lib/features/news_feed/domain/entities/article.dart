import 'package:equatable/equatable.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

/// A news article as the app uses it.
///
/// Pure domain value: no serialization. The data layer maps NewsAPI's
/// article object onto this and drops records that break its guarantees
/// (D11):
/// - [url], [title], [source] and [publishedAt] are always present.
///   Articles missing any of them, and `[Removed]` placeholders, never
///   reach the domain.
/// - [publishedAt] is in UTC. `DateTime ==` also compares `isUtc`, so the
///   mapper must normalise it.
///
/// [url] is the article's identity (D1): it is the Hive key, and code that
/// asks "is this the same article?" compares [url]. `==` compares every
/// field, so an updated article (new title, new image) counts as a change.
final class Article extends Equatable {
  /// Creates an article. The nullable fields are `required` so every call
  /// site states them explicitly; a forgotten field fails to compile.
  const Article({
    required this.url,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.author,
    required this.description,
    required this.content,
    required this.imageUrl,
  });

  /// The article's web address, and its identity (D1).
  final String url;

  /// The headline.
  final String title;

  /// The publisher.
  final ArticleSource source;

  /// When the article was published, in UTC.
  final DateTime publishedAt;

  /// The author, when NewsAPI provides one.
  final String? author;

  /// A short summary, when NewsAPI provides one.
  final String? description;

  /// The article body, when available. NewsAPI truncates it to about 200
  /// characters.
  final String? content;

  /// A related image's address (NewsAPI's `urlToImage`), when available.
  final String? imageUrl;

  @override
  List<Object?> get props => <Object?>[
    url,
    title,
    source,
    publishedAt,
    author,
    description,
    content,
    imageUrl,
  ];
}
