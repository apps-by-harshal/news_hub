import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/widgets/app_loading_indicator.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_state.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/article_list_tile.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/bookmarks_view.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

const String _url1 = 'https://example.com/saved-1';
const String _url2 = 'https://example.com/saved-2';
const String _url3 = 'https://example.com/saved-3';

const failures.Failure _cacheFailure = failures.CacheFailure(
  'diagnostic: box closed',
);
const failures.Failure _unexpectedFailure = failures.UnexpectedFailure(
  'diagnostic: boom',
);

/// `failure.userMessage` copy, spelled out.
const String _cacheCopy = "Couldn't read or save data on this device.";
const String _unexpectedCopy = 'Something went wrong. Please try again.';

/// The view's own copy, spelled out.
const String _title = 'Bookmarks';
const String _emptyTitle = 'No bookmarks yet';
const String _emptyHint =
    'Tap the bookmark icon on an article to save it here.';
const String _reloadPrefix = "Couldn't reload your bookmarks.";

BookmarksLoaded _loaded(List<String> urls, {failures.Failure? refreshFailure}) {
  return BookmarksLoaded(
    articles: urls.map(buildArticle).toList(),
    refreshFailure: refreshFailure,
  );
}

void main() {
  late MockBookmarksBloc bloc;
  late StreamController<BookmarksState> controller;

  setUpAll(() {
    registerFallbackValue(const BookmarksStarted());
    useNeverLoadingImages();
  });

  setUp(() {
    bloc = MockBookmarksBloc();
    controller = StreamController<BookmarksState>.broadcast();
  });

  tearDown(() async {
    clearImageCache();
    if (!controller.isClosed) {
      await controller.close();
    }
  });

  Future<void> pumpView(
    WidgetTester tester,
    BookmarksState initialState, {
    ValueChanged<Article>? onArticleTap,
  }) {
    whenListen(bloc, controller.stream, initialState: initialState);
    return tester.pumpApp(
      BlocProvider<BookmarksBloc>.value(
        value: bloc,
        child: BookmarksView(onArticleTap: onArticleTap ?? (_) {}),
      ),
    );
  }

  group('BookmarksView body', () {
    testWidgets('Loading: titled screen with a spinner, sends nothing', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, const BookmarksLoading());

      expect(find.widgetWithText(AppBar, _title), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('Failure: user copy (never message), Retry sends Refreshed', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, const BookmarksFailure(_cacheFailure));

      expect(find.text(_cacheCopy), findsOneWidget);
      expect(find.textContaining('diagnostic'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      verify(() => bloc.add(const BookmarksRefreshed())).called(1);
    });

    testWidgets('an empty list shows the empty state, no tiles', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, BookmarksLoaded(articles: const <Article>[]));

      expect(find.text(_emptyTitle), findsOneWidget);
      expect(find.text(_emptyHint), findsOneWidget);
      expect(find.byType(ArticleListTile), findsNothing);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('the empty state fits a small screen without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpView(tester, BookmarksLoaded(articles: const <Article>[]));

      expect(find.text(_emptyHint), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Loaded: one tile per article, in order, keyed by URL', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(<String>[_url1, _url2]));

      final Finder first = find.byKey(const ValueKey<String>(_url1));
      final Finder second = find.byKey(const ValueKey<String>(_url2));
      expect(first, findsOneWidget);
      expect(second, findsOneWidget);
      expect(
        tester.getTopLeft(first).dy,
        lessThan(tester.getTopLeft(second).dy),
      );
      expect(find.text('Title of $_url1'), findsOneWidget);
      expect(find.text(_emptyTitle), findsNothing);
      expect(find.byType(AppLoadingIndicator), findsNothing);
    });

    testWidgets('tapping a tile reports that article', (
      WidgetTester tester,
    ) async {
      final List<Article> tapped = <Article>[];
      await pumpView(
        tester,
        _loaded(<String>[_url1, _url2]),
        onArticleTap: tapped.add,
      );

      await tester.tap(find.text('Title of $_url2'));
      await tester.pump();

      expect(tapped, <Article>[buildArticle(_url2)]);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('follows the bloc from Loading to the list', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, const BookmarksLoading());

      controller.add(_loaded(<String>[_url3]));
      await tester.pump();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.text('Title of $_url3'), findsOneWidget);
    });
  });

  group('BookmarksView reload failure', () {
    testWidgets('keeps the list and shows one snackbar per new failure', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(<String>[_url1]));

      controller.add(_loaded(<String>[_url1], refreshFailure: _cacheFailure));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('$_reloadPrefix $_cacheCopy'), findsOneWidget);
      expect(find.text('Title of $_url1'), findsOneWidget);
      expect(find.textContaining('diagnostic'), findsNothing);

      // The same failure again is not a change: nothing is queued.
      controller.add(_loaded(<String>[_url1], refreshFailure: _cacheFailure));
      await tester.pump();
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a different failure replaces the snackbar', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(<String>[_url1]));

      controller.add(_loaded(<String>[_url1], refreshFailure: _cacheFailure));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      controller.add(
        _loaded(<String>[_url1], refreshFailure: _unexpectedFailure),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('$_reloadPrefix $_unexpectedCopy'), findsOneWidget);
      expect(find.text('$_reloadPrefix $_cacheCopy'), findsNothing);
    });

    testWidgets('a failure already in the first state shows no snackbar', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        _loaded(<String>[_url1], refreshFailure: _cacheFailure),
      );
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Title of $_url1'), findsOneWidget);
    });

    testWidgets('Retry (Failure → Loading → list) shows no snackbar', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, const BookmarksFailure(_cacheFailure));

      controller.add(const BookmarksLoading());
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsOneWidget);

      controller.add(_loaded(<String>[_url1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Title of $_url1'), findsOneWidget);
    });

    testWidgets('a successful reload shows no snackbar', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, _loaded(<String>[_url1]));

      controller.add(_loaded(<String>[_url2, _url1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Title of $_url2'), findsOneWidget);
    });
  });
}
