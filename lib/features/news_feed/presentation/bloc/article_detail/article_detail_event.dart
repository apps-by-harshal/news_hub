import 'package:equatable/equatable.dart';

/// Input to `ArticleDetailBloc`: what the article detail screen asks for.
///
/// Events carry no article: the bloc is created for one article (in the
/// page's `BlocProvider`) and takes it in its constructor. Both events are
/// handled with `droppable`, so a tap while one is in progress is ignored.
sealed class ArticleDetailEvent extends Equatable {
  const ArticleDetailEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The detail screen opened, or Retry after the bookmark status could not
/// be read: read whether the article is bookmarked.
final class ArticleDetailStarted extends ArticleDetailEvent {
  const ArticleDetailStarted();
}

/// The bookmark button was tapped: bookmark the article, or remove its
/// bookmark.
final class ArticleDetailBookmarkToggled extends ArticleDetailEvent {
  const ArticleDetailBookmarkToggled();
}
