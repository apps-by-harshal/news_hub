import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/widgets/app_error_view.dart';
import 'package:news_hub/core/widgets/app_loading_indicator.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/domain/entities/paginated_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/pages/news_feed_page.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/news_feed_view.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

const String _networkCopy =
    "You're offline. Check your connection and try again.";

/// A single, last page 1 from the network.
Result<PaginatedArticles> _firstPageOf(List<Article> articles) {
  return Success<PaginatedArticles>(
    PaginatedArticles(
      items: articles,
      page: 1,
      hasMore: false,
      isFromCache: false,
    ),
  );
}

void main() {
  late MockNewsRepository repository;
  late Article first;
  late Article second;

  setUpAll(useNeverLoadingImages);

  setUp(() {
    repository = MockNewsRepository();
    first = buildArticle('https://example.com/first');
    second = buildArticle('https://example.com/second');
    getIt.registerFactory<GetTopHeadlines>(
      () => GetTopHeadlines(repository: repository),
    );
  });

  tearDown(() async {
    clearImageCache();
    await getIt.reset();
  });

  /// The repository call for page 1 of the default category.
  Future<Result<PaginatedArticles>> firstPage({required bool forceRefresh}) {
    return repository.getTopHeadlines(
      category: NewsCategory.general,
      page: 1,
      forceRefresh: forceRefresh,
    );
  }

  testWidgets('creates its bloc, starts it, and shows the loaded feed', (
    WidgetTester tester,
  ) async {
    final Completer<Result<PaginatedArticles>> pending =
        Completer<Result<PaginatedArticles>>();
    when(() => firstPage(forceRefresh: false))
        .thenAnswer((_) => pending.future);

    await tester.pumpApp(
      NewsFeedPage(onArticleTap: (Article _) {}, onBookmarksTap: () {}),
    );

    expect(find.byType(NewsFeedView), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);

    pending.complete(_firstPageOf(<Article>[first]));
    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text("You're all caught up"), findsOneWidget);
    verify(() => firstPage(forceRefresh: false)).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('passes the tapped article to onArticleTap', (
    WidgetTester tester,
  ) async {
    when(() => firstPage(forceRefresh: false))
        .thenAnswer((_) async => _firstPageOf(<Article>[first, second]));
    final List<Article> tapped = <Article>[];

    await tester.pumpApp(
      NewsFeedPage(onArticleTap: tapped.add, onBookmarksTap: () {}),
    );
    await tester.pump();
    await tester.tap(find.text(second.title));

    expect(tapped, <Article>[second]);
  });

  testWidgets('passes a Bookmarks tap to onBookmarksTap', (
    WidgetTester tester,
  ) async {
    when(() => firstPage(forceRefresh: false))
        .thenAnswer((_) async => _firstPageOf(<Article>[first]));
    int taps = 0;

    await tester.pumpApp(
      NewsFeedPage(onArticleTap: (Article _) {}, onBookmarksTap: () => taps++),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Bookmarks'));
    await tester.pump();

    expect(taps, 1);
    verify(() => firstPage(forceRefresh: false)).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('shows the failure copy, and Retry reloads with fresh data', (
    WidgetTester tester,
  ) async {
    when(() => firstPage(forceRefresh: false)).thenAnswer(
      (_) async => const Failure<PaginatedArticles>(
        failures.NetworkFailure('connection refused'),
      ),
    );
    when(() => firstPage(forceRefresh: true))
        .thenAnswer((_) async => _firstPageOf(<Article>[first]));

    await tester.pumpApp(
      NewsFeedPage(onArticleTap: (Article _) {}, onBookmarksTap: () {}),
    );
    await tester.pump();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text(_networkCopy), findsOneWidget);
    expect(find.textContaining('connection refused'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text(first.title), findsOneWidget);
    verifyInOrder(<void Function()>[
      () => firstPage(forceRefresh: false),
      () => firstPage(forceRefresh: true),
    ]);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('closes its bloc when removed, even with a request pending', (
    WidgetTester tester,
  ) async {
    final Completer<Result<PaginatedArticles>> pending =
        Completer<Result<PaginatedArticles>>();
    when(() => firstPage(forceRefresh: false))
        .thenAnswer((_) => pending.future);

    await tester.pumpApp(
      NewsFeedPage(onArticleTap: (Article _) {}, onBookmarksTap: () {}),
    );
    final NewsFeedBloc bloc = BlocProvider.of<NewsFeedBloc>(
      tester.element(find.byType(NewsFeedView)),
    );
    expect(bloc.isClosed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_firstPageOf(<Article>[first]));
    await tester.pump();

    expect(bloc.isClosed, isTrue);
    expect(tester.takeException(), isNull);
    verify(() => firstPage(forceRefresh: false)).called(1);
    verifyNoMoreInteractions(repository);
  });
}
