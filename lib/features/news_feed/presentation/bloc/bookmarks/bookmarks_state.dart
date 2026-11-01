import 'package:equatable/equatable.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/features/news_feed/domain/entities/article.dart';

/// What the bookmarks screen shows (Step 24, D19).
sealed class BookmarksState extends Equatable {
  const BookmarksState();
}

/// The bookmarks are being read for the first time, or again after a
/// failure (Retry). The bloc's initial state.
final class BookmarksLoading extends BookmarksState {
  const BookmarksLoading();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The bookmarks, newest first. An empty [articles] means nothing is
/// bookmarked.
///
/// [refreshFailure] is set when reading the bookmarks again failed: the list
/// on screen stays, and the view shows the failure once (CLAUDE.md §4.5).
final class BookmarksLoaded extends BookmarksState {
  /// Keeps an unmodifiable copy of [articles], so the state can't change
  /// after it is emitted.
  BookmarksLoaded({required List<Article> articles, this.refreshFailure})
    : articles = List<Article>.unmodifiable(articles);

  /// The bookmarked articles, newest first.
  final List<Article> articles;

  /// Why the last reload failed, or `null`. Cleared when the next reload
  /// starts.
  final failures.Failure? refreshFailure;

  @override
  List<Object?> get props => <Object?>[articles, refreshFailure];
}

/// The bookmarks could not be read and there is nothing to show.
final class BookmarksFailure extends BookmarksState {
  const BookmarksFailure(this.failure);

  /// Why reading the bookmarks failed. The view shows `failure.userMessage`.
  final failures.Failure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
