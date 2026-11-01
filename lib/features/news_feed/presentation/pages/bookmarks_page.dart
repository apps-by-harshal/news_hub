import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_event.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/bookmarks_view.dart';

/// The bookmarks route's page (Step 24, D19, D20, D23).
///
/// Creates the screen's [BookmarksBloc] from the get_it use case, starts it,
/// and lets [BlocProvider] close it when the page leaves the tree.
///
/// Navigation is the router's job: [onArticleTap] opens the article and
/// completes when the user comes back. The page then reloads the bookmarks,
/// because the article's bookmark may have been removed on the way. This page
/// never imports go_router.
class BookmarksPage extends StatelessWidget {
  /// Creates the bookmarks page.
  const BookmarksPage({required this.onArticleTap, super.key});

  /// Opens [Article] and completes when the user is back on this page.
  final Future<void> Function(Article article) onArticleTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BookmarksBloc>(
      create: (BuildContext context) =>
          BookmarksBloc(getBookmarks: getIt<GetBookmarks>())
            ..add(const BookmarksStarted()),
      child: Builder(
        builder: (BuildContext context) {
          return BookmarksView(
            onArticleTap: (Article article) {
              unawaited(
                _openThenReload(context.read<BookmarksBloc>(), article),
              );
            },
          );
        },
      ),
    );
  }

  /// Waits for the article to be closed, then reloads, unless the page (and
  /// with it the bloc) is gone by then: adding to a closed bloc throws.
  Future<void> _openThenReload(BookmarksBloc bloc, Article article) async {
    await onArticleTap(article);
    if (!bloc.isClosed) {
      bloc.add(const BookmarksRefreshed());
    }
  }
}
