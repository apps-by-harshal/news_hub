import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/entities/article.dart';
import '../../domain/usecases/get_top_headlines.dart';
import '../bloc/news_feed/news_feed_bloc.dart';
import '../bloc/news_feed/news_feed_event.dart';
import '../widgets/news_feed_view.dart';

/// The feed route's page.
///
/// Creates the screen's [NewsFeedBloc] from the get_it use case, starts it,
/// and lets [BlocProvider] close it when the page leaves the tree. Navigation
/// is the router's job: it arrives through [onArticleTap] and
/// [onBookmarksTap], so this page never imports go_router.
class NewsFeedPage extends StatelessWidget {
  /// Creates the feed page.
  const NewsFeedPage({
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
    return BlocProvider<NewsFeedBloc>(
      create: (BuildContext context) =>
          NewsFeedBloc(getTopHeadlines: getIt<GetTopHeadlines>())
            ..add(const NewsFeedStarted()),
      child: NewsFeedView(
        onArticleTap: onArticleTap,
        onBookmarksTap: onBookmarksTap,
      ),
    );
  }
}
