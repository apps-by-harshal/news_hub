import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart' as failures;
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../domain/entities/article.dart';
import '../bloc/bookmarks/bookmarks_bloc.dart';
import '../bloc/bookmarks/bookmarks_event.dart';
import '../bloc/bookmarks/bookmarks_state.dart';
import 'article_list_tile.dart';

/// The bookmarks screen: every saved article, newest first, driven by the
/// [BookmarksBloc] above it.
///
/// It reads state and sends events only; the page creates the bloc, sends
/// `BookmarksStarted`, and reloads after [onArticleTap]'s navigation returns.
class BookmarksView extends StatelessWidget {
  const BookmarksView({required this.onArticleTap, super.key});

  /// Called with the article whose row was tapped.
  final ValueChanged<Article> onArticleTap;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookmarksBloc, BookmarksState>(
      listenWhen: (BookmarksState previous, BookmarksState current) {
        final failures.Failure? failure = _refreshFailureOf(current);
        return failure != null && failure != _refreshFailureOf(previous);
      },
      listener: (BuildContext context, BookmarksState state) {
        final failures.Failure? failure = _refreshFailureOf(state);
        if (failure == null) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                "Couldn't reload your bookmarks. ${failure.userMessage}",
              ),
            ),
          );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Bookmarks')),
        body: _BookmarksBody(onArticleTap: onArticleTap),
      ),
    );
  }
}

/// The reload failure a state carries, or `null` for any other state.
failures.Failure? _refreshFailureOf(BookmarksState state) {
  return switch (state) {
    BookmarksLoaded(:final failures.Failure? refreshFailure) => refreshFailure,
    BookmarksLoading() || BookmarksFailure() => null,
  };
}

class _BookmarksBody extends StatelessWidget {
  const _BookmarksBody({required this.onArticleTap});

  final ValueChanged<Article> onArticleTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarksBloc, BookmarksState>(
      builder: (BuildContext context, BookmarksState state) {
        return switch (state) {
          BookmarksLoading() => const AppLoadingIndicator(),
          BookmarksFailure(:final failures.Failure failure) => AppErrorView(
            message: failure.userMessage,
            onRetry: () =>
                context.read<BookmarksBloc>().add(const BookmarksRefreshed()),
          ),
          BookmarksLoaded(:final List<Article> articles)
              when articles.isEmpty =>
            const _EmptyBookmarks(),
          BookmarksLoaded(:final List<Article> articles) => ListView.builder(
            itemCount: articles.length,
            itemBuilder: (BuildContext context, int index) {
              final Article article = articles[index];
              return ArticleListTile(
                key: ValueKey<String>(article.url),
                article: article,
                onTap: () => onArticleTap(article),
              );
            },
          ),
        };
      },
    );
  }
}

/// Shown when nothing is bookmarked: what the screen is for and how to fill
/// it. Scrolls if the screen is too short.
class _EmptyBookmarks extends StatelessWidget {
  const _EmptyBookmarks();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: <Widget>[
            Icon(
              Icons.bookmark_border,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Text(
              'No bookmarks yet',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Tap the bookmark icon on an article to save it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
