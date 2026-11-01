import 'package:equatable/equatable.dart';

import 'article.dart';

/// One page of articles, plus whether another page can be requested and
/// whether it came from the local cache.
///
/// Pure domain value: no serialization. It carries no `totalResults`:
/// the repository works out [hasMore]. Because the mapper drops
/// invalid articles, [items] can hold fewer than a full page even when
/// [hasMore] is `true`.
///
/// Not `const`: the constructor copies [items] into an unmodifiable list.
final class PaginatedArticles extends Equatable {
  /// Creates a page. [items] is copied, so later changes to the caller's
  /// list do not affect this page. [page] is 1-based.
  PaginatedArticles({
    required List<Article> items,
    required this.page,
    required this.hasMore,
    required this.isFromCache,
  }) : assert(page >= 1, 'page is 1-based'),
       items = List<Article>.unmodifiable(items);

  /// The articles on this page, in the order NewsAPI returned them.
  /// Unmodifiable: adding or removing throws an [UnsupportedError].
  final List<Article> items;

  /// The 1-based page number.
  final int page;

  /// Whether another page can be requested.
  final bool hasMore;

  /// Whether this page was served from the local cache because the network
  /// request failed. The presentation layer shows it as offline.
  ///
  /// The repository guarantees that a cached page is always `page: 1` with
  /// `hasMore: false`.
  final bool isFromCache;

  @override
  List<Object?> get props => <Object?>[items, page, hasMore, isFromCache];
}
