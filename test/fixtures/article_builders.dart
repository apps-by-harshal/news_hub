// Shared article builders for model, mapper, data source and repository
// tests.
//
// `buildArticle(url)` and `buildArticleJson(url)` are a matched pair: mapping
// `buildArticleJson(url)` through `ArticleModel.fromJson` and the article
// mapper yields exactly `buildArticle(url)`. Every value is derived from
// `url`, so two different URLs give articles that differ in every field.
// Pass an absolute `http`/`https` URL, or the mapper drops the article.
//
// `buildArticleWithoutOptionals(url)` is the same article with
// every nullable field `null`, for storage round trips.

import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

/// The `publishedAt` of every built article, in UTC.
final DateTime builtArticlePublishedAt = DateTime.utc(2026, 10, 30, 8, 30);

/// The raw NewsAPI form of [builtArticlePublishedAt].
const String builtArticlePublishedAtJson = '2026-10-30T08:30:00Z';

/// Returns a valid [Article] with every optional field set.
Article buildArticle(String url) => Article(
  url: url,
  title: 'Title of $url',
  source: ArticleSource(id: 'Source id of $url', name: 'Source of $url'),
  publishedAt: builtArticlePublishedAt,
  author: 'Author of $url',
  description: 'Description of $url',
  content: 'Content of $url',
  imageUrl: '$url/image.jpg',
);

/// Returns a valid [Article] with every nullable field (`source.id`,
/// `author`, `description`, `content`, `imageUrl`) set to `null`; the
/// required fields match [buildArticle].
Article buildArticleWithoutOptionals(String url) => Article(
  url: url,
  title: 'Title of $url',
  source: ArticleSource(id: null, name: 'Source of $url'),
  publishedAt: builtArticlePublishedAt,
  author: null,
  description: null,
  content: null,
  imageUrl: null,
);

/// Returns the raw NewsAPI JSON that maps to exactly [buildArticle].
///
/// Each call returns new, mutable maps, so a test can change a field
/// (`..['title'] = null`) or remove one (`..remove('title')`) without
/// affecting other tests.
Map<String, Object?> buildArticleJson(String url) => <String, Object?>{
  'source': <String, Object?>{
    'id': 'Source id of $url',
    'name': 'Source of $url',
  },
  'author': 'Author of $url',
  'title': 'Title of $url',
  'description': 'Description of $url',
  'url': url,
  'urlToImage': '$url/image.jpg',
  'publishedAt': builtArticlePublishedAtJson,
  'content': 'Content of $url',
};
