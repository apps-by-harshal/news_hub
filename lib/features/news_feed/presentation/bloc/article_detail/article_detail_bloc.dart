import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_state.dart';

/// Drives the bookmark button of one article's detail screen (Step 21).
///
/// Created per screen in the page's `BlocProvider` (never registered in
/// get_it), which also closes it when the page is popped.
///
/// Event handling, both `droppable`:
/// - [ArticleDetailStarted]: reads the bookmark status, from
///   [ArticleDetailLoading] (the initial state) or as a retry from
///   [ArticleDetailStatusFailure], which first shows loading again. Ignored
///   once the status is known.
/// - [ArticleDetailBookmarkToggled]: only from [ArticleDetailReady] with no
///   toggle in progress, because the repository's toggle is read-then-write
///   (D12). A failure keeps the shown status and sets `toggleFailure`.
interface class ArticleDetailBloc
    extends Bloc<ArticleDetailEvent, ArticleDetailState> {
  /// Creates the bloc in [ArticleDetailLoading] for [article]. Callers pass
  /// `getBookmarkStatus:` and `toggleBookmark:`.
  ArticleDetailBloc({
    required this._getBookmarkStatus,
    required this._toggleBookmark,
    required Article article,
  }) : super(ArticleDetailLoading(article: article)) {
    on<ArticleDetailStarted>(
      _onStarted,
      transformer: droppable<ArticleDetailStarted>(),
    );
    on<ArticleDetailBookmarkToggled>(
      _onBookmarkToggled,
      transformer: droppable<ArticleDetailBookmarkToggled>(),
    );
  }

  final GetBookmarkStatus _getBookmarkStatus;
  final ToggleBookmark _toggleBookmark;

  Future<void> _onStarted(
    ArticleDetailStarted event,
    Emitter<ArticleDetailState> emit,
  ) async {
    final ArticleDetailState current = state;
    if (current is ArticleDetailReady) return;
    if (current is ArticleDetailStatusFailure) {
      emit(ArticleDetailLoading(article: current.article));
    }

    final Article article = current.article;
    final Result<bool> result = await _getBookmarkStatus(article.url);

    emit(switch (result) {
      Success<bool>(:final bool value) => ArticleDetailReady(
        article: article,
        isBookmarked: value,
      ),
      Failure<bool>(:final failures.Failure failure) =>
        ArticleDetailStatusFailure(article: article, failure: failure),
    });
  }

  Future<void> _onBookmarkToggled(
    ArticleDetailBookmarkToggled event,
    Emitter<ArticleDetailState> emit,
  ) async {
    final ArticleDetailState current = state;
    if (current is! ArticleDetailReady || current.isToggling) return;

    final ArticleDetailReady toggling = current.copyWith(
      isToggling: true,
      toggleFailure: () => null,
    );
    emit(toggling);

    final Result<bool> result = await _toggleBookmark(current.article);

    emit(switch (result) {
      Success<bool>(:final bool value) => toggling.copyWith(
        isBookmarked: value,
        isToggling: false,
      ),
      Failure<bool>(:final failures.Failure failure) => toggling.copyWith(
        isToggling: false,
        toggleFailure: () => failure,
      ),
    });
  }
}
