/// Names and paths of the app's routes.
///
/// Code navigates by **name** (`context.pushNamed(RouteNames.article, …)`);
/// paths appear only in the route table and its redirects. go_router names
/// each page after its route (`state.name ?? state.path`), so these names are
/// also what `AppRouterObserver` logs.
abstract final class RouteNames {
  /// The headlines feed, the app's start screen.
  static const String feed = 'feed';

  /// Path of [feed].
  static const String feedPath = '/';

  /// The detail screen of one article, which arrives as the route's `extra`.
  static const String article = 'article';

  /// Path of [article]. Opened without an article in `extra` (deep link, web
  /// refresh), it redirects to [feedPath].
  static const String articlePath = '/article';

  /// The list of bookmarked articles, opened from the feed's app bar.
  static const String bookmarks = 'bookmarks';

  /// Path of [bookmarks].
  static const String bookmarksPath = '/bookmarks';
}
