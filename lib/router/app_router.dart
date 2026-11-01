import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/news_feed/domain/entities/article.dart';
import '../features/news_feed/presentation/pages/article_detail_page.dart';
import '../features/news_feed/presentation/pages/bookmarks_page.dart';
import '../features/news_feed/presentation/pages/news_feed_page.dart';
import 'route_names.dart';

/// Builds the app's [GoRouter].
///
/// - [RouteNames.feedPath] shows [NewsFeedPage]; tapping an article pushes
///   [RouteNames.article] with the [Article] as `extra`, and the app bar's
///   Bookmarks button pushes [RouteNames.bookmarks].
/// - [RouteNames.bookmarksPath] shows [BookmarksPage]; tapping an article
///   pushes [RouteNames.article] and completes when it is popped, so the page
///   can reload.
/// - [RouteNames.articlePath] shows [ArticleDetailPage] for the [Article] in
///   `extra`. Without one (a deep link, a web refresh, restored state) it
///   redirects to the feed, because an article can't be rebuilt from the URL.
///
/// Pages never import go_router: navigation reaches them as a callback
/// or a constructor value. The router is app-level wiring, so it lives in
/// `lib/router/`, not `core/`. The caller owns the router
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
            onBookmarksTap: () {
              unawaited(context.pushNamed<void>(RouteNames.bookmarks));
            },
          );
        },
      ),
      GoRoute(
        path: RouteNames.bookmarksPath,
        name: RouteNames.bookmarks,
        builder: (BuildContext context, GoRouterState state) {
          return BookmarksPage(
            onArticleTap: (Article article) async {
              await context.pushNamed<void>(RouteNames.article, extra: article);
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
