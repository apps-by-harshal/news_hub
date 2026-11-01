import 'package:equatable/equatable.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

/// Input to `NewsFeedBloc`: what the feed screen asks for.
///
/// Each subtype has its own handler and event transformer in the bloc
/// (Step 21). Events carry only what the user chose; page numbers and the
/// current category come from the bloc's state.
sealed class NewsFeedEvent extends Equatable {
  const NewsFeedEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The feed screen opened: load page 1 of the default category.
///
/// Handled only while the feed is still in its initial state, so a rebuilt
/// page never fetches twice.
final class NewsFeedStarted extends NewsFeedEvent {
  const NewsFeedStarted();
}

/// Pull-to-refresh, or Retry after a failed first load: fetch page 1 of the
/// current category with fresh data.
final class NewsFeedRefreshed extends NewsFeedEvent {
  const NewsFeedRefreshed();
}

/// The list scrolled near its end, or Retry after a failed page: fetch the
/// next page of the current category.
final class NewsFeedNextPageRequested extends NewsFeedEvent {
  const NewsFeedNextPageRequested();
}

/// The user picked a category chip: load page 1 of [category].
final class NewsFeedCategoryChanged extends NewsFeedEvent {
  const NewsFeedCategoryChanged(this.category);

  /// The category to show.
  final NewsCategory category;

  @override
  List<Object?> get props => <Object?>[category];
}
