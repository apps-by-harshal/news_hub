import 'package:equatable/equatable.dart';

import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/news_category.dart';
import '../entities/paginated_articles.dart';
import '../repositories/news_repository.dart';

/// Fetches one page of top headlines for a category.
///
/// Passes the repository's [Result] through unchanged, including the
/// offline fallback (`isFromCache`) described on
/// [NewsRepository.getTopHeadlines].
final class GetTopHeadlines
    implements UseCase<PaginatedArticles, GetTopHeadlinesParams> {
  /// Creates the use case. Callers pass `repository:`.
  const GetTopHeadlines({required this._repository});

  final NewsRepository _repository;

  @override
  Future<Result<PaginatedArticles>> call(GetTopHeadlinesParams params) {
    return _repository.getTopHeadlines(
      category: params.category,
      page: params.page,
      forceRefresh: params.forceRefresh,
    );
  }
}

/// Input for [GetTopHeadlines].
final class GetTopHeadlinesParams extends Equatable {
  /// Creates the params. [page] is 1-based and must be at least 1.
  const GetTopHeadlinesParams({
    required this.category,
    required this.page,
    required this.forceRefresh,
  }) : assert(page >= 1, 'page is 1-based');

  /// The category to fetch.
  final NewsCategory category;

  /// The 1-based page number.
  final int page;

  /// `true` for pull-to-refresh: ask the network for fresh data instead of
  /// a cached HTTP response.
  final bool forceRefresh;

  @override
  List<Object?> get props => <Object?>[category, page, forceRefresh];
}
