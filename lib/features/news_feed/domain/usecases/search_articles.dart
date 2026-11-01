import 'package:equatable/equatable.dart';
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/usecase/usecase.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';

/// Searches all articles for a query.
///
/// Trims the query before calling [NewsRepository.searchArticles], which
/// requires a trimmed, non-blank query. Passes the repository's [Result]
/// through unchanged.
final class SearchArticles
    implements UseCase<PaginatedArticles, SearchArticlesParams> {
  /// Creates the use case. Callers pass `repository:`.
  const SearchArticles({required this._repository});

  final NewsRepository _repository;

  @override
  Future<Result<PaginatedArticles>> call(SearchArticlesParams params) {
    return _repository.searchArticles(
      query: params.query.trim(),
      page: params.page,
    );
  }
}

/// Input for [SearchArticles].
final class SearchArticlesParams extends Equatable {
  /// Creates the params. [query] must contain a non-whitespace character;
  /// it is stored as given and trimmed by [SearchArticles]. [page] is
  /// 1-based and must be at least 1.
  ///
  /// Not `const`: the blank-query check calls `String.trim`, which a
  /// `const` constructor cannot.
  SearchArticlesParams({required this.query, required this.page})
    : assert(query.trim().isNotEmpty, 'query must not be blank'),
      assert(page >= 1, 'page is 1-based');

  /// The search text, exactly as the caller passed it.
  final String query;

  /// The 1-based page number.
  final int page;

  @override
  List<Object?> get props => <Object?>[query, page];
}
