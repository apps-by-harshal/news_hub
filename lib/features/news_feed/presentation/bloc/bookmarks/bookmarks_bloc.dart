import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/usecase/usecase.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_state.dart';

/// The bookmarks screen's logic (Step 24, D19, D23).
///
/// - [BookmarksStarted] reads the bookmarks once, from the initial
///   [BookmarksLoading]; it is ignored in any other state.
/// - [BookmarksRefreshed] reads them again: from [BookmarksLoaded] it keeps
///   the list on screen and reports a failure as `refreshFailure`; from
///   [BookmarksFailure] it is Retry (`BookmarksLoading`, then the result); it
///   is ignored while [BookmarksLoading].
///
/// Both events are `droppable`: a second one while the first runs is dropped,
/// never cancels the first (a cancelled Retry could leave the screen in
/// `BookmarksLoading`). Neither can run while the other does, so no request id
/// is needed. Created by the page's `BlocProvider`, never registered in get_it
/// (D19); `interface class` so widget tests can mock it.
interface class BookmarksBloc extends Bloc<BookmarksEvent, BookmarksState> {
  /// Creates the bloc. Callers pass `getBookmarks:`.
  BookmarksBloc({required this._getBookmarks})
    : super(const BookmarksLoading()) {
    on<BookmarksStarted>(
      _onStarted,
      transformer: droppable<BookmarksStarted>(),
    );
    on<BookmarksRefreshed>(
      _onRefreshed,
      transformer: droppable<BookmarksRefreshed>(),
    );
  }

  final GetBookmarks _getBookmarks;

  Future<void> _onStarted(
    BookmarksStarted event,
    Emitter<BookmarksState> emit,
  ) async {
    if (state is! BookmarksLoading) {
      return;
    }
    emit(await _load());
  }

  Future<void> _onRefreshed(
    BookmarksRefreshed event,
    Emitter<BookmarksState> emit,
  ) async {
    switch (state) {
      case BookmarksLoading():
        return;
      case BookmarksFailure():
        emit(const BookmarksLoading());
        emit(await _load());
      case BookmarksLoaded(
        :final List<Article> articles,
        :final failures.Failure? refreshFailure,
      ):
        if (refreshFailure != null) {
          // Cleared first, so the same failure twice is still a new state.
          emit(BookmarksLoaded(articles: articles));
        }
        final Result<List<Article>> result = await _getBookmarks(
          const NoParams(),
        );
        emit(switch (result) {
          Success<List<Article>>(:final List<Article> value) => BookmarksLoaded(
            articles: value,
          ),
          Failure<List<Article>>(:final failures.Failure failure) =>
            BookmarksLoaded(articles: articles, refreshFailure: failure),
        });
    }
  }

  /// Reads the bookmarks into the state that shows them, or the failure.
  Future<BookmarksState> _load() async {
    final Result<List<Article>> result = await _getBookmarks(const NoParams());
    return switch (result) {
      Success<List<Article>>(:final List<Article> value) => BookmarksLoaded(
        articles: value,
      ),
      Failure<List<Article>>(:final failures.Failure failure) =>
        BookmarksFailure(failure),
    };
  }
}
