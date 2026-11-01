import 'dart:math' as math;

import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';
import 'package:news_hub/features/news_feed/data/models/article_model.dart';
import 'package:news_hub/features/news_feed/data/models/article_source_model.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';

/// Title NewsAPI uses for moderated articles.
const String _removedTitle = '[Removed]';

/// Host NewsAPI uses in the URL of moderated articles.
const String _removedHost = 'removed.com';

/// NewsAPI's truncation marker at the end of `content`, e.g. `[+2345 chars]`.
final RegExp _truncationMarker = RegExp(r'\s*\[\+\d+ chars\]\s*$');

/// Maps a raw [ArticleModel] to a domain [Article] (D11).
extension ArticleModelMapper on ArticleModel {
  /// Returns the [Article], or `null` when the article must be dropped.
  ///
  /// Dropped when any required field is null, missing or blank (`url`,
  /// `title`, `source`, `source.name`, `publishedAt`), when `url` is not an
  /// absolute `http`/`https` URL, when `publishedAt` cannot be parsed, or
  /// when it is a moderated placeholder (title `[Removed]` or host
  /// `removed.com`).
  ///
  /// Every string is trimmed; blank optional fields become `null`;
  /// `urlToImage` becomes `imageUrl` (`null` when not an `http`/`https`
  /// URL); `publishedAt` is converted to UTC, and a timestamp without an
  /// offset is read as UTC; a trailing `[+N chars]` marker is removed from
  /// `content`.
  Article? toEntityOrNull() {
    final String? validUrl = _httpUrlOrNull(url);
    final String? validTitle = _trimmedOrNull(title);
    final ArticleSource? validSource = _sourceOrNull(source);
    final DateTime? utcPublishedAt = _utcOrNull(publishedAt);

    if (validUrl == null ||
        validTitle == null ||
        validSource == null ||
        utcPublishedAt == null) {
      return null;
    }
    if (validTitle == _removedTitle ||
        Uri.parse(validUrl).host == _removedHost) {
      return null;
    }

    return Article(
      url: validUrl,
      title: validTitle,
      source: validSource,
      publishedAt: utcPublishedAt,
      author: _trimmedOrNull(author),
      description: _trimmedOrNull(description),
      content: _contentOrNull(content),
      imageUrl: _httpUrlOrNull(urlToImage),
    );
  }
}

/// Maps a list of raw articles, skipping the ones that are dropped.
extension ArticleModelListMapper on Iterable<ArticleModel> {
  /// Returns the valid [Article]s in their original order.
  List<Article> toEntities() =>
      map((ArticleModel model) => model.toEntityOrNull()).nonNulls.toList();
}

/// Maps a NewsAPI response envelope to a [RemoteArticlesPage] (D13).
extension NewsResponseModelMapper on NewsResponseModel {
  /// Returns the page of valid articles.
  ///
  /// Missing `articles` become an empty list; a missing or negative
  /// `totalResults` becomes `0`, which ends paging. `status` is not
  /// checked: error responses are non-2xx and handled by `ErrorInterceptor`.
  RemoteArticlesPage toRemoteArticlesPage() => RemoteArticlesPage(
    articles: (articles ?? const <ArticleModel>[]).toEntities(),
    totalResults: math.max(0, totalResults ?? 0),
  );
}

/// Maps a domain [Article] to the [ArticleLocalModel] stored in Hive (D13).
extension ArticleLocalMapper on Article {
  /// Returns the local model, copying every field and flattening the source
  /// into `sourceId` / `sourceName`. `publishedAt` is copied unchanged, so it
  /// stays in UTC with its microseconds.
  ArticleLocalModel toLocalModel() => ArticleLocalModel(
    url: url,
    title: title,
    sourceId: source.id,
    sourceName: source.name,
    publishedAt: publishedAt,
    author: author,
    description: description,
    content: content,
    imageUrl: imageUrl,
  );
}

/// Maps an [ArticleLocalModel] read from Hive back to a domain [Article].
extension ArticleLocalModelMapper on ArticleLocalModel {
  /// Returns the [Article], copying every field and rebuilding the source.
  ///
  /// No validation: only entities that already passed [ArticleModelMapper]
  /// are ever stored, so the stored values are trusted as they are.
  Article toEntity() => Article(
    url: url,
    title: title,
    source: ArticleSource(id: sourceId, name: sourceName),
    publishedAt: publishedAt,
    author: author,
    description: description,
    content: content,
    imageUrl: imageUrl,
  );
}

String? _trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _httpUrlOrNull(String? value) {
  final String? trimmed = _trimmedOrNull(value);
  if (trimmed == null) {
    return null;
  }
  final Uri? uri = Uri.tryParse(trimmed);
  final bool isHttp =
      uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty;
  return isHttp ? trimmed : null;
}

ArticleSource? _sourceOrNull(ArticleSourceModel? model) {
  final String? name = _trimmedOrNull(model?.name);
  if (model == null || name == null) {
    return null;
  }
  return ArticleSource(id: _trimmedOrNull(model.id), name: name);
}

DateTime? _utcOrNull(String? value) {
  final String? trimmed = _trimmedOrNull(value);
  final DateTime? parsed = trimmed == null ? null : DateTime.tryParse(trimmed);
  if (parsed == null) {
    return null;
  }
  if (parsed.isUtc) {
    // `Z` or an explicit offset: Dart has already converted it to UTC.
    return parsed;
  }
  // No offset: NewsAPI documents UTC, so read the wall-clock time as UTC
  // instead of the device's local time zone.
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

String? _contentOrNull(String? value) =>
    _trimmedOrNull(value?.replaceFirst(_truncationMarker, ''));
