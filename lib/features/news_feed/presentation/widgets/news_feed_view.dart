import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart' as failures;
import '../../../../core/utils/failure_message.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_indicator.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/news_category.dart';
import '../bloc/news_feed/news_feed_bloc.dart';
import '../bloc/news_feed/news_feed_event.dart';
import '../bloc/news_feed/news_feed_state.dart';
import 'article_list_tile.dart';
import 'category_chips.dart';
import 'offline_banner.dart';

/// The feed screen: category chips, the offline banner and the article list,
/// all driven by the [NewsFeedBloc] above it.
///
/// It reads state and sends events only; the page creates the bloc and sends
/// `NewsFeedStarted`, and navigation arrives through [onArticleTap] and
/// [onBookmarksTap].
class NewsFeedView extends StatelessWidget {
  const NewsFeedView({
    required this.onArticleTap,
    required this.onBookmarksTap,
    super.key,
  });

  /// Called with the article whose row was tapped.
  final ValueChanged<Article> onArticleTap;

  /// Called when the Bookmarks button in the app bar is tapped.
  final VoidCallback onBookmarksTap;

  @override
  Widget build(BuildContext context) {
    return BlocListener<NewsFeedBloc, NewsFeedState>(
      listenWhen: (NewsFeedState previous, NewsFeedState current) {
        final failures.Failure? failure = _refreshFailureOf(current);
        return failure != null && failure != _refreshFailureOf(previous);
      },
      listener: (BuildContext context, NewsFeedState state) {
        final failures.Failure? failure = _refreshFailureOf(state);
        if (failure == null) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                "Couldn't refresh the feed. ${failure.userMessage}",
              ),
            ),
          );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('News Hub'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.bookmarks_outlined),
              tooltip: 'Bookmarks',
              onPressed: onBookmarksTap,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BlocSelector<NewsFeedBloc, NewsFeedState, NewsCategory>(
              selector: (NewsFeedState state) => state.category,
              builder: (BuildContext context, NewsCategory category) {
                return CategoryChips(
                  selected: category,
                  onSelected: (NewsCategory selected) => context
                      .read<NewsFeedBloc>()
                      .add(NewsFeedCategoryChanged(selected)),
                );
              },
            ),
            BlocSelector<NewsFeedBloc, NewsFeedState, bool>(
              selector: (NewsFeedState state) =>
                  state is NewsFeedLoaded && state.isOffline,
              builder: (BuildContext context, bool isOffline) {
                return isOffline
                    ? const OfflineBanner()
                    : const SizedBox.shrink();
              },
            ),
            Expanded(child: _FeedBody(onArticleTap: onArticleTap)),
          ],
        ),
      ),
    );
  }
}

/// The refresh failure a state carries, or `null` for any other state.
failures.Failure? _refreshFailureOf(NewsFeedState state) {
  return switch (state) {
    NewsFeedLoaded(:final failures.Failure? refreshFailure) => refreshFailure,
    NewsFeedInitial() || NewsFeedLoading() || NewsFeedFailure() => null,
  };
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.onArticleTap});

  final ValueChanged<Article> onArticleTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewsFeedBloc, NewsFeedState>(
      builder: (BuildContext context, NewsFeedState state) {
        return switch (state) {
          NewsFeedInitial() || NewsFeedLoading() => const AppLoadingIndicator(),
          NewsFeedFailure(:final failures.Failure failure) => AppErrorView(
            message: failure.userMessage,
            onRetry: () =>
                context.read<NewsFeedBloc>().add(const NewsFeedRefreshed()),
          ),
          NewsFeedLoaded() => _ArticleList(
            state: state,
            onArticleTap: onArticleTap,
          ),
        };
      },
    );
  }
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({required this.state, required this.onArticleTap});

  final NewsFeedLoaded state;
  final ValueChanged<Article> onArticleTap;

  @override
  Widget build(BuildContext context) {
    final List<Article> articles = state.articles;
    return RefreshIndicator(
      onRefresh: () => _refresh(context.read<NewsFeedBloc>()),
      child: ListView.builder(
        // A short list must still overscroll, or pull-to-refresh can't start.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: articles.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == articles.length) {
            return _Footer(state: state);
          }
          final Article article = articles[index];
          return ArticleListTile(
            key: ValueKey<String>(article.url),
            article: article,
            onTap: () => onArticleTap(article),
          );
        },
      ),
    );
  }
}

/// Sends `NewsFeedRefreshed` and completes when the refresh is over: the
/// first state that is not a refreshing list (a category change or a closed
/// bloc also ends it). The future is created before the event is added, so
/// no state can slip past it.
Future<void> _refresh(NewsFeedBloc bloc) async {
  final Future<NewsFeedState> done = bloc.stream.firstWhere(
    (NewsFeedState state) => state is! NewsFeedLoaded || !state.isRefreshing,
    orElse: () => bloc.state,
  );
  bloc.add(const NewsFeedRefreshed());
  await done;
}

/// The last list item: what happens after the loaded articles.
class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final NewsFeedLoaded state;

  @override
  Widget build(BuildContext context) {
    final failures.Failure? loadMoreFailure = state.loadMoreFailure;
    if (state.isLoadingMore) {
      return const _FooterSpinner();
    }
    if (loadMoreFailure != null) {
      return _LoadMoreError(message: loadMoreFailure.userMessage);
    }
    if (state.isOffline) {
      return const SizedBox.shrink();
    }
    if (!state.hasMore) {
      return const _CaughtUp();
    }
    if (state.isRefreshing) {
      return const SizedBox.shrink();
    }
    return _LoadMoreTrigger(key: ValueKey<String>('load-more-${state.page}'));
  }
}

/// Asks for the next page once, after its first frame. Keyed by page, so a
/// rebuild for the same page keeps this state and never asks twice.
class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger({super.key});

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        context.read<NewsFeedBloc>().add(const NewsFeedNextPageRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) => const _FooterSpinner();
}

class _FooterSpinner extends StatelessWidget {
  const _FooterSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading more'),
      ),
    );
  }
}

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 8,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          FilledButton.tonal(
            onPressed: () => context.read<NewsFeedBloc>().add(
              const NewsFeedNextPageRequested(),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        "You're all caught up",
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
