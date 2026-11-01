import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/usecase/usecase.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';

/// Reports whether the article with a given URL is bookmarked.
///
/// The parameter is the article's URL, its identity (D11); no params class
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
