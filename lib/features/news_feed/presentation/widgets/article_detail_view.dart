import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/utils/date_formatter.dart';
import 'package:news_hub/core/utils/failure_message.dart';
import 'package:news_hub/core/widgets/app_network_image.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_state.dart';

/// The article detail screen (Step 22-3, D20).
///
/// Reads `ArticleDetailBloc` from the tree (provided by `ArticleDetailPage`)
/// and builds its own `Scaffold`:
/// - the body shows the article: a 16:9 image, title, `source · date`,
///   byline, description, content and the URL as selectable text; missing
///   optional fields are left out;
/// - the AppBar's bookmark action follows the state: disabled while the
///   status loads or could not be read (with a Retry next to it), filled or
///   outlined once known, disabled while a toggle runs;
/// - a new `toggleFailure` shows one snackbar with `userMessage` (D9).
class ArticleDetailView extends StatelessWidget {
  /// Creates the detail view.
  const ArticleDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ArticleDetailBloc, ArticleDetailState>(
      listenWhen: (ArticleDetailState previous, ArticleDetailState current) {
        final failures.Failure? failure = _toggleFailureOf(current);
        return failure != null && failure != _toggleFailureOf(previous);
      },
      listener: (BuildContext context, ArticleDetailState state) {
        final failures.Failure? failure = _toggleFailureOf(state);
        if (failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  "Couldn't update the bookmark. ${failure.userMessage}",
                ),
              ),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(actions: const <Widget>[_BookmarkActions()]),
        body: BlocSelector<ArticleDetailBloc, ArticleDetailState, Article>(
          selector: (ArticleDetailState state) => state.article,
          builder: (BuildContext context, Article article) =>
              _ArticleContent(article: article),
        ),
      ),
    );
  }
}

/// The failure of the last toggle, if the state carries one.
failures.Failure? _toggleFailureOf(ArticleDetailState state) => switch (state) {
  ArticleDetailReady(:final failures.Failure? toggleFailure) => toggleFailure,
  ArticleDetailLoading() || ArticleDetailStatusFailure() => null,
};

/// The AppBar's bookmark button, plus a Retry after a failed status read.
class _BookmarkActions extends StatelessWidget {
  const _BookmarkActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArticleDetailBloc, ArticleDetailState>(
      builder: (BuildContext context, ArticleDetailState state) {
        return switch (state) {
          ArticleDetailLoading() => const _DisabledBookmarkButton(),
          ArticleDetailReady(
            :final bool isBookmarked,
            :final bool isToggling,
          ) =>
            IconButton(
              icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
              tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
              onPressed: isToggling
                  ? null
                  : () => context.read<ArticleDetailBloc>().add(
                      const ArticleDetailBookmarkToggled(),
                    ),
            ),
          ArticleDetailStatusFailure() => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _DisabledBookmarkButton(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Retry loading bookmark',
                onPressed: () => context.read<ArticleDetailBloc>().add(
                  const ArticleDetailStarted(),
                ),
              ),
            ],
          ),
        };
      },
    );
  }
}

/// The bookmark button while the status is unknown.
class _DisabledBookmarkButton extends StatelessWidget {
  const _DisabledBookmarkButton();

  @override
  Widget build(BuildContext context) {
    return const IconButton(
      icon: Icon(Icons.bookmark_border),
      tooltip: 'Bookmark',
      onPressed: null,
    );
  }
}

/// The scrollable article body.
class _ArticleContent extends StatelessWidget {
  const _ArticleContent({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? author = article.author;
    final String? description = article.description;
    final String? content = article.content;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: AppNetworkImage(url: article.imageUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: <Widget>[
                Text(article.title, style: textTheme.headlineSmall),
                Text(
                  '${article.source.name} · '
                  '${DateFormatter.shortDate(article.publishedAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (author != null)
                  Text('By $author', style: textTheme.labelLarge),
                if (description != null)
                  Text(description, style: textTheme.bodyLarge),
                if (content != null) Text(content, style: textTheme.bodyMedium),
                SelectableText(
                  article.url,
                  style: textTheme.bodySmall?.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
