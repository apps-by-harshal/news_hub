import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart' as failures;
import '../../../domain/entities/article.dart';

/// What the article detail screen shows, emitted by `ArticleDetailBloc`.
///
/// Every state carries the [article], so the screen always shows its
/// content; the states only differ in what the bookmark button shows.
sealed class ArticleDetailState extends Equatable {
  const ArticleDetailState({required this.article});

  /// The article on screen.
  final Article article;

  @override
  List<Object?> get props => <Object?>[article];
}

/// The bookmark status is being read. This is the bloc's initial state.
final class ArticleDetailLoading extends ArticleDetailState {
  const ArticleDetailLoading({required super.article});
}

/// The bookmark status is known.
///
/// While [isToggling] is `true`, further taps are ignored. After a
/// failed toggle, [isBookmarked] is unchanged (the repository changed
/// nothing) and [toggleFailure] drives a snackbar until the next toggle
/// starts. The UI picks its copy by failure type and never shows `message`.
final class ArticleDetailReady extends ArticleDetailState {
  const ArticleDetailReady({
    required super.article,
    required this.isBookmarked,
    this.isToggling = false,
    this.toggleFailure,
  });

  /// Whether the article is bookmarked.
  final bool isBookmarked;

  /// Whether a toggle is in progress.
  final bool isToggling;

  /// Why the last toggle failed, until the next toggle starts.
  final failures.Failure? toggleFailure;

  /// Returns a copy with the given fields replaced.
  ///
  /// [toggleFailure] is passed as a callback so it can be cleared:
  /// `copyWith(toggleFailure: () => null)`. The article never changes.
  ArticleDetailReady copyWith({
    bool? isBookmarked,
    bool? isToggling,
    failures.Failure? Function()? toggleFailure,
  }) {
    return ArticleDetailReady(
      article: article,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isToggling: isToggling ?? this.isToggling,
      toggleFailure: toggleFailure != null
          ? toggleFailure()
          : this.toggleFailure,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    article,
    isBookmarked,
    isToggling,
    toggleFailure,
  ];
}

/// The bookmark status could not be read. The screen shows the bookmark
/// button disabled with a Retry (`ArticleDetailStarted`); toggles are
/// ignored in this state.
final class ArticleDetailStatusFailure extends ArticleDetailState {
  const ArticleDetailStatusFailure({
    required super.article,
    required this.failure,
  });

  /// Why the status could not be read. The UI picks its copy by failure
  /// type.
  final failures.Failure failure;

  @override
  List<Object?> get props => <Object?>[article, failure];
}
