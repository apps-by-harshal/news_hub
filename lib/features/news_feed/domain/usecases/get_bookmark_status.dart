import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/news_repository.dart';

/// Reports whether the article with a given URL is bookmarked.
///
/// The parameter is the article's URL, its identity; no params class
/// is needed for one value. Returns [NewsRepository.isBookmarked]'s
/// [Result] unchanged. The article detail screen uses it to show the
/// bookmark icon in the right state when it opens.
final class GetBookmarkStatus implements UseCase<bool, String> {
  /// Creates the use case. Callers pass `repository:`.
  const GetBookmarkStatus({required this._repository});

  final NewsRepository _repository;

  @override
  Future<Result<bool>> call(String params) {
    return _repository.isBookmarked(params);
  }
}
