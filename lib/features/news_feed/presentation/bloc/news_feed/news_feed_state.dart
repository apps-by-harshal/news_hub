import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart' as failures;
import '../../../domain/entities/article.dart';
import '../../../domain/entities/news_category.dart';

/// What the feed screen shows, emitted by `NewsFeedBloc`.
///
/// Every state carries the selected [category], so the category chips can
/// show the selection while loading and after a failure too.
sealed class NewsFeedState extends Equatable {
  const NewsFeedState({required this.category});

  /// The category being shown or loaded.
  final NewsCategory category;

  @override
  List<Object?> get props => <Object?>[category];
}

/// Before the first load. The category is the default, `general`.
final class NewsFeedInitial extends NewsFeedState {
  const NewsFeedInitial() : super(category: NewsCategory.general);
}

/// Page 1 of [category] is loading and there is no list to show yet.
final class NewsFeedLoading extends NewsFeedState {
  const NewsFeedLoading({required super.category});
}

/// A list is shown.
///
/// [isLoadingMore] / [loadMoreFailure] describe the next page, and
/// [isRefreshing] / [refreshFailure] describe a pull-to-refresh. In both
/// cases a failure keeps the list on screen: the footer shows
/// [loadMoreFailure] with a Retry button, and a snackbar shows
/// [refreshFailure]. The bloc clears both failures when the next action
/// starts, so the same failure twice in a row still produces a new state.
///
/// The UI picks its copy by failure type and never shows `message`.
///
/// Not `const`: the constructor copies [articles] into an unmodifiable list.
final class NewsFeedLoaded extends NewsFeedState {
  /// Creates a loaded state. [articles] is copied, so later changes to the
  /// caller's list do not affect this state. [page] is 1-based.
  NewsFeedLoaded({
    required super.category,
    required List<Article> articles,
    required this.page,
    required this.hasMore,
    required this.isOffline,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.loadMoreFailure,
    this.refreshFailure,
  }) : assert(page >= 1, 'page is 1-based'),
       articles = List<Article>.unmodifiable(articles);

  /// Every article loaded so far, in display order, without duplicate URLs.
  /// Unmodifiable: adding or removing throws an [UnsupportedError].
  final List<Article> articles;

  /// The last page loaded (1-based).
  final int page;

  /// Whether another page can be requested.
  final bool hasMore;

  /// Whether the list came from the local cache
  /// (`PaginatedArticles.isFromCache`). The screen shows the offline
  /// banner.
  final bool isOffline;

  /// Whether the next page is being fetched.
  final bool isLoadingMore;

  /// Whether a pull-to-refresh is in progress.
  final bool isRefreshing;

  /// Why the last next-page request failed, until the next action starts.
  final failures.Failure? loadMoreFailure;

  /// Why the last refresh failed, until the next action starts.
  final failures.Failure? refreshFailure;

  /// Returns a copy with the given fields replaced.
  ///
  /// The failures are passed as callbacks so they can be cleared:
  /// `copyWith(loadMoreFailure: () => null)`. [category] cannot change here;
  /// a category change always goes through [NewsFeedLoading].
  NewsFeedLoaded copyWith({
    List<Article>? articles,
    int? page,
    bool? hasMore,
    bool? isOffline,
    bool? isLoadingMore,
    bool? isRefreshing,
    failures.Failure? Function()? loadMoreFailure,
    failures.Failure? Function()? refreshFailure,
  }) {
    return NewsFeedLoaded(
      category: category,
      articles: articles ?? this.articles,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isOffline: isOffline ?? this.isOffline,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadMoreFailure: loadMoreFailure != null
          ? loadMoreFailure()
          : this.loadMoreFailure,
      refreshFailure: refreshFailure != null
          ? refreshFailure()
          : this.refreshFailure,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    category,
    articles,
    page,
    hasMore,
    isOffline,
    isLoadingMore,
    isRefreshing,
    loadMoreFailure,
    refreshFailure,
  ];
}

/// Page 1 of [category] could not be loaded and there is no list to show.
/// The screen shows an error view with Retry (`NewsFeedRefreshed`).
final class NewsFeedFailure extends NewsFeedState {
  const NewsFeedFailure({required super.category, required this.failure});

  /// Why loading failed. The UI picks its copy by failure type.
  final failures.Failure failure;

  @override
  List<Object?> get props => <Object?>[category, failure];
}
