import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';

/// One category's cached top headlines, as stored in the `articles_cache`
/// Hive box (one value per category key, D13).
///
/// A wrapper instead of a bare `List`: Hive reads a bare list value back as
/// `List<dynamic>`, while the adapter generated for this class (from
/// `lib/hive_adapters.dart`, Step 17a) casts [articles] to
/// `List<ArticleLocalModel>`, so the box stays fully typed.
///
/// Plain class, like [ArticleLocalModel]: field indices are pinned by name
/// in `lib/hive_adapters.g.yaml`, so renaming or removing a field needs a
/// migration.
final class CachedArticlesLocalModel {
  /// Creates the cached list for one category, in feed order.
  const CachedArticlesLocalModel({required this.articles});

  /// The cached articles in feed order: page 1 first, later pages appended,
  /// at most one entry per URL (D13).
  final List<ArticleLocalModel> articles;
}
