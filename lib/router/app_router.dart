import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/presentation/pages/article_detail_page.dart';
import 'package:news_hub/features/news_feed/presentation/pages/news_feed_page.dart';
import 'package:news_hub/router/route_names.dart';

/// Builds the app's [GoRouter] (Step 22a).
///
/// - [RouteNames.feedPath] shows [NewsFeedPage]; tapping an article pushes
///   [RouteNames.article] with the [Article] as `extra`.
/// - [RouteNames.articlePath] shows [ArticleDetailPage] for the [Article] in
///   `extra`. Without one (a deep link, a web refresh, restored state) it
///   redirects to the feed, because an article can't be rebuilt from the URL.
///
/// Pages never import go_router (D20): navigation reaches them as a callback
/// or a constructor value. The router is app-level wiring, so it lives in
/// `lib/router/`, not `core/` (CLAUDE.md §3.1). The caller owns the router
/// and disposes it.
GoRouter createAppRouter({
  List<NavigatorObserver> observers = const <NavigatorObserver>[],
  String initialLocation = RouteNames.feedPath,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    observers: observers,
    routes: <RouteBase>[
      GoRoute(
        path: RouteNames.feedPath,
        name: RouteNames.feed,
        builder: (BuildContext context, GoRouterState state) {
          return NewsFeedPage(
            onArticleTap: (Article article) {
              unawaited(
                context.pushNamed<void>(RouteNames.article, extra: article),
              );
            },
          );
        },
      ),
      GoRoute(
        path: RouteNames.articlePath,
        name: RouteNames.article,
        redirect: (BuildContext context, GoRouterState state) {
          return state.extra is Article ? null : RouteNames.feedPath;
        },
        builder: (BuildContext context, GoRouterState state) {
          return ArticleDetailPage(article: state.extra as Article);
        },
      ),
    ],
  );
}
