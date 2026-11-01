import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/article.dart';
import '../repositories/news_repository.dart';

/// Bookmarks an article, or removes its bookmark if it already has one.
///
/// Takes the [Article] directly; no params class is needed for one value.
/// Returns the new state from [NewsRepository.toggleBookmark] unchanged:
/// `true` when the article is now bookmarked, `false` when the bookmark
/// was removed.
final class ToggleBookmark implements UseCase<bool, Article> {
  /// Creates the use case. Callers pass `repository:`.
  const ToggleBookmark({required this._repository});

  final NewsRepository _repository;

  @override
  Future<Result<bool>> call(Article params) {
    return _repository.toggleBookmark(params);
  }
}
