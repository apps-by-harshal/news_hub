/// An `Article` as stored in Hive, for the feed cache and bookmarks (D13).
///
/// A plain class on purpose: its `TypeAdapter` is generated from the
/// `@GenerateAdapters` list in `lib/hive_adapters.dart` (Step 17a), and every
/// field below becomes a persisted Hive field. The source is flattened into
/// [sourceId] and [sourceName], so one adapter covers the whole article.
///
/// Field indices are pinned by field name in `lib/hive_adapters.g.yaml`.
/// Adding a field is safe; renaming or removing one needs a migration,
/// because existing boxes would no longer match the schema.
///
/// Mapping to and from the entity lives in `article_mapper.dart`.
final class ArticleLocalModel {
  /// Creates a local model. Every field is `required`, including the
  /// nullable ones, so a forgotten field fails to compile (same rule as the
  /// entity, D11).
  const ArticleLocalModel({
    required this.url,
    required this.title,
    required this.sourceId,
    required this.sourceName,
    required this.publishedAt,
    required this.author,
    required this.description,
    required this.content,
    required this.imageUrl,
  });

  /// The article's identity (D1, D11).
  final String url;

  /// The headline.
  final String title;

  /// NewsAPI's source id, if the source has one.
  final String? sourceId;

  /// The source's display name.
  final String sourceName;

  /// When the article was published, in UTC. Hive's default `DateTime`
  /// adapter keeps `isUtc` and microseconds (verified 2026-10-31).
  final DateTime publishedAt;

  /// The author, if known.
  final String? author;

  /// A short summary, if any.
  final String? description;

  /// The (truncated) body text, if any.
  final String? content;

  /// The image URL, if any.
  final String? imageUrl;
}
