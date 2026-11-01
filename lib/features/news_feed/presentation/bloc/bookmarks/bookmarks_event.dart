import 'package:equatable/equatable.dart';

/// Something that happened on the bookmarks screen (Step 24, D19).
///
/// Neither event carries data: the screen always lists every bookmark.
sealed class BookmarksEvent extends Equatable {
  const BookmarksEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The screen opened: load the bookmarks for the first time.
final class BookmarksStarted extends BookmarksEvent {
  const BookmarksStarted();
}

/// Load the bookmarks again: the user came back from an article (whose
/// bookmark may have changed) or tapped Retry after a failure.
final class BookmarksRefreshed extends BookmarksEvent {
  const BookmarksRefreshed();
}
