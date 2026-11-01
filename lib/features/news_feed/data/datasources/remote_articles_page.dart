import 'package:equatable/equatable.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';

/// One page of results from the remote data source, already mapped to
/// entities.
///
/// [articles] holds only the articles that survived mapping: invalid and
/// moderated (`[Removed]`) entries are dropped by the mapper, so the list
/// may be shorter than the requested page size.
///
/// [totalResults] is the raw total reported by the API across all pages.
/// The repository derives `hasMore` from it (D11), never from the length
/// of [articles].
final class RemoteArticlesPage extends Equatable {
  /// Copies [articles] into an unmodifiable list.
  ///
  /// [totalResults] must be `>= 0`.
  RemoteArticlesPage({
    required List<Article> articles,
    required this.totalResults,
  }) : articles = List<Article>.unmodifiable(articles),
       assert(totalResults >= 0, 'totalResults must be >= 0');

  /// The mapped articles of this page, in API order. Unmodifiable.
  final List<Article> articles;

  /// The total number of results the API reports for the whole query.
  final int totalResults;

  @override
  List<Object?> get props => <Object?>[articles, totalResults];
}
