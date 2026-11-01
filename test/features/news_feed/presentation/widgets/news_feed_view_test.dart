import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/widgets/app_loading_indicator.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_state.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/news_feed_view.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/offline_banner.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

const String _url1 = 'https://example.com/a1';
const String _url2 = 'https://example.com/a2';
const String _url3 = 'https://example.com/a3';

const failures.Failure _networkFailure = failures.NetworkFailure(
  'diagnostic: socket closed',
);
const failures.Failure _unexpectedFailure = failures.UnexpectedFailure(
  'diagnostic: boom',
);

/// `failure.userMessage` copy (D20), spelled out.
const String _networkCopy =
    "You're offline. Check your connection and try again.";
const String _unexpectedCopy = 'Something went wrong. Please try again.';

NewsFeedLoaded _loaded({
  List<Article>? articles,
  NewsCategory category = NewsCategory.general,
  int page = 1,
  bool hasMore = false,
  bool isOffline = false,
  bool isLoadingMore = false,
  bool isRefreshing = false,
  failures.Failure? loadMoreFailure,
  failures.Failure? refreshFailure,
}) {
  return NewsFeedLoaded(
    category: category,
    articles: articles ?? <Article>[buildArticle(_url1), buildArticle(_url2)],
    page: page,
    hasMore: hasMore,
    isOffline: isOffline,
    isLoadingMore: isLoadingMore,
    isRefreshing: isRefreshing,
    loadMoreFailure: loadMoreFailure,
    refreshFailure: refreshFailure,
  );
}

bool _chipSelected(WidgetTester tester, String label) {
  return tester
      .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
      .selected;
}

void main() {
  late MockNewsFeedBloc bloc;
  late StreamController<NewsFeedState> controller;

  setUpAll(() {
    registerFallbackValue(const NewsFeedStarted());
    useNeverLoadingImages();
  });

  setUp(() {
    bloc = MockNewsFeedBloc();
    controller = StreamController<NewsFeedState>.broadcast();
  });

  tearDown(() async {
    clearImageCache();
    // Test 16 closes the controller inside the fake-async test body; its
    // done future can't complete out here, so don't wait on it twice.
    if (!controller.isClosed) {
      await controller.close();
    }
  });

  Future<void> pumpView(
    WidgetTester tester,
    NewsFeedState initialState, {
    ValueChanged<Article>? onArticleTap,
  }) {
    whenListen(bloc, controller.stream, initialState: initialState);
    return tester.pumpApp(
      BlocProvider<NewsFeedBloc>.value(
        value: bloc,
        child: NewsFeedView(onArticleTap: onArticleTap ?? (_) {}),
      ),
    );
  }

  group('NewsFeedView body', () {
    testWidgets('Initial: spinner, General selected, sends nothing', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, const NewsFeedInitial());

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(_chipSelected(tester, 'General'), isTrue);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('Loading: spinner and the loading category selected', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        const NewsFeedLoading(category: NewsCategory.sports),
      );

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(_chipSelected(tester, 'Sports'), isTrue);
      expect(_chipSelected(tester, 'General'), isFalse);
    });

    testWidgets('Failure: user copy (never message), Retry sends Refreshed', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        const NewsFeedFailure(
          category: NewsCategory.general,
          failure: _networkFailure,
        ),
      );

      expect(find.text(_networkCopy), findsOneWidget);
      expect(find.textContaining('diagnostic'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => bloc.add(const NewsFeedRefreshed())).called(1);
    });

    testWidgets('Loaded: one tile per article, in order, keyed by URL', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded());

      final Finder first = find.byKey(const ValueKey<String>(_url1));
      final Finder second = find.byKey(const ValueKey<String>(_url2));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      expect(find.text('Title of $_url1'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('tapping a tile reports that article', (
      WidgetTester tester,
    ) async {
      final List<Article> tapped = <Article>[];
      await pumpView(tester, _loaded(), onArticleTap: tapped.add);

      await tester.tap(find.text('Title of $_url2'));
      await tester.pump();

      expect(tapped, <Article>[buildArticle(_url2)]);
    });
  });

  group('NewsFeedView chips and banner', () {
    testWidgets('tapping a category chip sends CategoryChanged', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded());

      await tester.tap(find.text('Business'));
      await tester.pump();

      verify(
        () => bloc.add(const NewsFeedCategoryChanged(NewsCategory.business)),
      ).called(1);
    });

    testWidgets('shows the offline banner for a cached list', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(isOffline: true));

      expect(find.byType(OfflineBanner), findsOneWidget);
    });

    testWidgets('hides the offline banner for a fresh list and while loading', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded());
      expect(find.byType(OfflineBanner), findsNothing);

      controller.add(const NewsFeedLoading(category: NewsCategory.general));
      await tester.pump();
      expect(find.byType(OfflineBanner), findsNothing);
    });
  });

  group('NewsFeedView footer', () {
    testWidgets('requests the next page once per page', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(hasMore: true));
      verify(() => bloc.add(const NewsFeedNextPageRequested())).called(1);

      // An equal state for the same page rebuilds without a new request.
      controller.add(_loaded(hasMore: true));
      await tester.pump();
      verifyNever(() => bloc.add(const NewsFeedNextPageRequested()));

      controller.add(
        _loaded(
          articles: <Article>[
            buildArticle(_url1),
            buildArticle(_url2),
            buildArticle(_url3),
          ],
          page: 2,
          hasMore: true,
        ),
      );
      await tester.pump();
      verify(() => bloc.add(const NewsFeedNextPageRequested())).called(1);
    });

    testWidgets(
      'sends nothing while offline, refreshing, loading more or after a '
      'load-more failure',
      (WidgetTester tester) async {
        final List<NewsFeedLoaded> blocked = <NewsFeedLoaded>[
          _loaded(hasMore: true, isOffline: true),
          _loaded(hasMore: true, isRefreshing: true),
          _loaded(hasMore: true, isLoadingMore: true),
          _loaded(hasMore: true, loadMoreFailure: _unexpectedFailure),
        ];

        for (final NewsFeedLoaded state in blocked) {
          await pumpView(tester, state);
          verifyNever(() => bloc.add(any()));
        }
      },
    );

    testWidgets('shows a spinner while the next page loads', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(hasMore: true, isLoadingMore: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text("You're all caught up"), findsNothing);
    });

    testWidgets('a load-more failure shows its copy and Retry asks again', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        _loaded(hasMore: true, loadMoreFailure: _unexpectedFailure),
      );

      expect(find.text(_unexpectedCopy), findsOneWidget);
      expect(find.textContaining('diagnostic'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => bloc.add(const NewsFeedNextPageRequested())).called(1);
    });

    testWidgets('says "You\'re all caught up" when there are no more pages', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded());

      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('NewsFeedView refresh', () {
    testWidgets('a new refresh failure shows one snackbar', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded());

      controller.add(_loaded(refreshFailure: _networkFailure));
      await tester.pump();
      expect(
        find.text("Couldn't refresh the feed. $_networkCopy"),
        findsOneWidget,
      );

      // The same failure again is not a change: nothing is queued.
      controller.add(_loaded(refreshFailure: _networkFailure));
      await tester.pump();
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'pull-to-refresh sends Refreshed and ends when refreshing stops',
      (WidgetTester tester) async {
        await pumpView(tester, _loaded());

        await tester.fling(
          find.text('Title of $_url1'),
          const Offset(0, 300),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        verify(() => bloc.add(const NewsFeedRefreshed())).called(1);
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);

        controller.add(_loaded(isRefreshing: true));
        await tester.pump();
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);

        controller.add(_loaded(articles: <Article>[buildArticle(_url3)]));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(RefreshProgressIndicator), findsNothing);
        expect(find.text('Title of $_url3'), findsOneWidget);
      },
    );

    testWidgets('pull-to-refresh also ends when the bloc stream closes', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded());

      await tester.fling(
        find.text('Title of $_url1'),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      verify(() => bloc.add(const NewsFeedRefreshed())).called(1);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      // No state ever arrives: the stream just closes (bloc closed).
      unawaited(controller.close());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(RefreshProgressIndicator), findsNothing);
      expect(find.text('Title of $_url1'), findsOneWidget);
    });
  });
}
