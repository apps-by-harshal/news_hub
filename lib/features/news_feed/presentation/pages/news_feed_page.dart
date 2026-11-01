import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_event.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/news_feed_view.dart';

/// The feed route's page (Step 22-3, D19, D20).
///
/// Creates the screen's [NewsFeedBloc] from the get_it use case, starts it,
/// and lets [BlocProvider] close it when the page leaves the tree. Navigation
/// is the router's job: it arrives through [onArticleTap], so this page never
/// imports go_router.
class NewsFeedPage extends StatelessWidget {
  /// Creates the feed page.
  const NewsFeedPage({required this.onArticleTap, super.key});

  /// Called with the article whose row was tapped.
  final ValueChanged<Article> onArticleTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NewsFeedBloc>(
      create: (BuildContext context) =>
          NewsFeedBloc(getTopHeadlines: getIt<GetTopHeadlines>())
            ..add(const NewsFeedStarted()),
      child: NewsFeedView(onArticleTap: onArticleTap),
    );
  }
}
