import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/theme/app_theme.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';
import 'package:news_hub/features/news_feed/presentation/pages/article_detail_page.dart';
import 'package:news_hub/features/news_feed/presentation/pages/bookmarks_page.dart';
import 'package:news_hub/features/news_feed/presentation/pages/news_feed_page.dart';
import 'package:news_hub/router/app_router.dart';
import 'package:news_hub/router/route_names.dart';

import '../fixtures/article_builders.dart';
import '../helpers/mocks.dart';
import '../helpers/network_image_helpers.dart';

/// Records the names of pushed and popped routes, as go_router sets them
/// (`state.name ?? state.path`).
class _RecordingObserver extends NavigatorObserver {
  final List<String?> pushed = <String?>[];
  final List<String?> popped = <String?>[];

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) {
    pushed.add(route.settings.name);
  }

  @override
  void didPop(Route<Object?> route, Route<Object?>? previousRoute) {
    popped.add(route.settings.name);
  }
}

/// Pumps [router] in a themed `MaterialApp.router` (as `App` will) and lets
/// the first page load. The router is disposed when the test ends.
Future<void> _pumpRouterApp(WidgetTester tester, GoRouter router) async {
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
  await _settle(tester);
}

/// Lets pending use-case futures complete and page transitions finish.
///
/// Not `pumpAndSettle()`: a spinner on screen would never settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late MockNewsRepository repository;
  late Article first;
  late Article second;

  setUpAll(useNeverLoadingImages);

  setUp(() {
    repository = MockNewsRepository();
    first = buildArticle('https://example.com/router-first');
    second = buildArticle('https://example.com/router-second');

    getIt
      ..registerFactory<GetTopHeadlines>(
        () => GetTopHeadlines(repository: repository),
      )
      ..registerFactory<GetBookmarkStatus>(
        () => GetBookmarkStatus(repository: repository),
      )
      ..registerFactory<GetBookmarks>(
        () => GetBookmarks(repository: repository),
      )
      ..registerFactory<ToggleBookmark>(
        () => ToggleBookmark(repository: repository),
      );

    when(
      () => repository.getTopHeadlines(
        category: NewsCategory.general,
        page: 1,
        forceRefresh: false,
      ),
    ).thenAnswer(
      (_) async => Success<PaginatedArticles>(
        PaginatedArticles(
          items: <Article>[first, second],
          page: 1,
          hasMore: false,
          isFromCache: false,
        ),
      ),
    );
    when(() => repository.isBookmarked(second.url))
        .thenAnswer((_) async => const Success<bool>(false));
  });

  tearDown(() async {
    clearImageCache();
    await getIt.reset();
  });

  group('createAppRouter', () {
    testWidgets('starts on the feed and loads the general headlines', (
      WidgetTester tester,
    ) async {
      await _pumpRouterApp(tester, createAppRouter());

      expect(find.byType(NewsFeedPage), findsOneWidget);
      expect(find.byType(ArticleDetailPage), findsNothing);
      expect(find.text(first.title), findsOneWidget);
      expect(find.text(second.title), findsOneWidget);
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    });

    testWidgets('tapping an article opens the detail page of that article', (
      WidgetTester tester,
    ) async {
      await _pumpRouterApp(tester, createAppRouter());

      await tester.tap(find.text(second.title));
      await _settle(tester);

      expect(find.byType(NewsFeedPage), findsNothing);
      expect(find.byType(ArticleDetailPage), findsOneWidget);
      expect(
        tester
            .widget<ArticleDetailPage>(find.byType(ArticleDetailPage))
            .article,
        second,
      );
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verify(() => repository.isBookmarked(second.url)).called(1);
      verifyNoMoreInteractions(repository);
    });

    testWidgets('back from the detail page returns to the same feed', (
      WidgetTester tester,
    ) async {
      await _pumpRouterApp(tester, createAppRouter());
      await tester.tap(find.text(second.title));
      await _settle(tester);

      await tester.pageBack();
      await _settle(tester);

      expect(find.byType(ArticleDetailPage), findsNothing);
      expect(find.byType(NewsFeedPage), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      // The feed's bloc survived the push: no second load.
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verify(() => repository.isBookmarked(second.url)).called(1);
      verifyNoMoreInteractions(repository);
    });

    testWidgets('opening /article without an article redirects to the feed', (
      WidgetTester tester,
    ) async {
      await _pumpRouterApp(
        tester,
        createAppRouter(initialLocation: RouteNames.articlePath),
      );

      expect(find.byType(ArticleDetailPage), findsNothing);
      expect(find.byType(NewsFeedPage), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    });

    testWidgets('going to /article with a non-article extra stays on the '
        'feed', (WidgetTester tester) async {
      final GoRouter router = createAppRouter();
      await _pumpRouterApp(tester, router);

      router.go(RouteNames.articlePath, extra: 'not an article');
      await _settle(tester);

      expect(find.byType(ArticleDetailPage), findsNothing);
      expect(find.byType(NewsFeedPage), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verifyNoMoreInteractions(repository);
    });

    testWidgets('observers see the article push and pop by route name', (
      WidgetTester tester,
    ) async {
      final _RecordingObserver observer = _RecordingObserver();
      await _pumpRouterApp(
        tester,
        createAppRouter(observers: <NavigatorObserver>[observer]),
      );
      final int pushesBefore = observer.pushed.length;

      await tester.tap(find.text(second.title));
      await _settle(tester);
      await tester.pageBack();
      await _settle(tester);

      expect(observer.pushed.sublist(pushesBefore), <String?>[
        RouteNames.article,
      ]);
      expect(observer.popped, <String?>[RouteNames.article]);
    });

    testWidgets('the Bookmarks button opens the bookmarks page, and back '
        'returns to the same feed', (WidgetTester tester) async {
      when(() => repository.getBookmarks())
          .thenAnswer((_) async => Success<List<Article>>(<Article>[second]));
      await _pumpRouterApp(tester, createAppRouter());

      await tester.tap(find.byTooltip('Bookmarks'));
      await _settle(tester);

      expect(find.byType(BookmarksPage), findsOneWidget);
      expect(find.byType(NewsFeedPage), findsNothing);
      expect(find.text(second.title), findsOneWidget);
      expect(find.text(first.title), findsNothing);

      await tester.pageBack();
      await _settle(tester);

      expect(find.byType(BookmarksPage), findsNothing);
      expect(find.byType(NewsFeedPage), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      // The feed's bloc survived the push: no second load.
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verify(() => repository.getBookmarks()).called(1);
      verifyNoMoreInteractions(repository);
    });

    testWidgets('an article opened from the bookmarks reloads them on the way '
        'back', (WidgetTester tester) async {
      final List<Result<List<Article>>> answers = <Result<List<Article>>>[
        Success<List<Article>>(<Article>[first, second]),
        // The bookmark of `second` was removed on its detail page.
        Success<List<Article>>(<Article>[first]),
      ];
      when(() => repository.getBookmarks())
          .thenAnswer((_) async => answers.removeAt(0));
      final GoRouter router = createAppRouter();
      await _pumpRouterApp(tester, router);
      await tester.tap(find.byTooltip('Bookmarks'));
      await _settle(tester);

      await tester.tap(find.text(second.title));
      await _settle(tester);

      expect(find.byType(ArticleDetailPage), findsOneWidget);
      expect(
        tester
            .widget<ArticleDetailPage>(find.byType(ArticleDetailPage))
            .article,
        second,
      );

      await tester.pageBack();
      await _settle(tester);

      expect(find.byType(BookmarksPage), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      expect(find.text(second.title), findsNothing);
      verify(
        () => repository.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          forceRefresh: false,
        ),
      ).called(1);
      verify(() => repository.isBookmarked(second.url)).called(1);
      verify(() => repository.getBookmarks()).called(2);
      verifyNoMoreInteractions(repository);
    });
  });
}
