import '../../../../core/result/result.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/article.dart';
import '../repositories/news_repository.dart';

/// Lists every bookmarked article, newest first.
///
/// Takes [NoParams]: the list has no filter or paging. Returns
/// [NewsRepository.getBookmarks]'s [Result] unchanged. The bookmarks screen
/// uses it when it opens and again when the user comes back to it.
final class GetBookmarks implements UseCase<List<Article>, NoParams> {
  /// Creates the use case. Callers pass `repository:`.
  const GetBookmarks({required this._repository});

  final NewsRepository _repository;

  @override
  Future<Result<List<Article>>> call(NoParams params) {
    return _repository.getBookmarks();
  }
}
