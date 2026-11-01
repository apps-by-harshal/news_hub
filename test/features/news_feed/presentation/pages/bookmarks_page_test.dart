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
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/pages/bookmarks_page.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/bookmarks_view.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

const String _cacheCopy = "Couldn't read or save data on this device.";

Result<List<Article>> _success(List<Article> articles) {
  return Success<List<Article>>(articles);
}

/// A navigation that never returns (the detail page stays open).
Future<void> _neverReturns(Article _) => Completer<void>().future;

void main() {
  late MockNewsRepository repository;
  late Article first;
  late Article second;

  setUpAll(useNeverLoadingImages);

  setUp(() {
    repository = MockNewsRepository();
    first = buildArticle('https://example.com/saved-first');
    second = buildArticle('https://example.com/saved-second');
    getIt.registerFactory<GetBookmarks>(
      () => GetBookmarks(repository: repository),
    );
  });

  tearDown(() async {
    clearImageCache();
    await getIt.reset();
  });

  testWidgets('creates its bloc, starts it, and shows the bookmarks', (
    WidgetTester tester,
  ) async {
    final Completer<Result<List<Article>>> pending =
        Completer<Result<List<Article>>>();
    when(() => repository.getBookmarks()).thenAnswer((_) => pending.future);

    await tester.pumpApp(const BookmarksPage(onArticleTap: _neverReturns));

    expect(find.byType(BookmarksView), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);

    pending.complete(_success(<Article>[first, second]));
    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(second.title), findsOneWidget);
    verify(() => repository.getBookmarks()).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('opens the tapped article, then reloads once it returns', (
    WidgetTester tester,
  ) async {
    final List<Result<List<Article>>> answers = <Result<List<Article>>>[
      _success(<Article>[first, second]),
      // The user removed `first` on the detail page.
      _success(<Article>[second]),
    ];
    when(() => repository.getBookmarks())
        .thenAnswer((_) async => answers.removeAt(0));
    final Completer<void> navigation = Completer<void>();
    final List<Article> opened = <Article>[];

    await tester.pumpApp(
      BookmarksPage(
        onArticleTap: (Article article) {
          opened.add(article);
          return navigation.future;
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.text(first.title));
    await tester.pump();

    // Still on the detail page: no reload yet.
    expect(opened, <Article>[first]);
    verify(() => repository.getBookmarks()).called(1);

    navigation.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text(first.title), findsNothing);
    expect(find.text(second.title), findsOneWidget);
    verify(() => repository.getBookmarks()).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('shows the failure copy, and Retry reads again', (
    WidgetTester tester,
  ) async {
    final List<Result<List<Article>>> answers = <Result<List<Article>>>[
      const Failure<List<Article>>(failures.CacheFailure('box closed')),
      _success(<Article>[first]),
    ];
    when(() => repository.getBookmarks())
        .thenAnswer((_) async => answers.removeAt(0));

    await tester.pumpApp(const BookmarksPage(onArticleTap: _neverReturns));
    await tester.pump();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text(_cacheCopy), findsOneWidget);
    expect(find.textContaining('box closed'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.byType(AppErrorView), findsNothing);
    expect(find.text(first.title), findsOneWidget);
    verify(() => repository.getBookmarks()).called(2);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('closes its bloc when removed, even with a read pending', (
    WidgetTester tester,
  ) async {
    final Completer<Result<List<Article>>> pending =
        Completer<Result<List<Article>>>();
    when(() => repository.getBookmarks()).thenAnswer((_) => pending.future);

    await tester.pumpApp(const BookmarksPage(onArticleTap: _neverReturns));
    final BookmarksBloc bloc = BlocProvider.of<BookmarksBloc>(
      tester.element(find.byType(BookmarksView)),
    );
    expect(bloc.isClosed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(_success(<Article>[first]));
    await tester.pump();

    expect(bloc.isClosed, isTrue);
    expect(tester.takeException(), isNull);
    verify(() => repository.getBookmarks()).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('a navigation that returns after the page is gone reloads '
      'nothing and throws nothing', (WidgetTester tester) async {
    when(() => repository.getBookmarks())
        .thenAnswer((_) async => _success(<Article>[first]));
    final Completer<void> navigation = Completer<void>();

    await tester.pumpApp(
      BookmarksPage(onArticleTap: (Article _) => navigation.future),
    );
    await tester.pump();
    final BookmarksBloc bloc = BlocProvider.of<BookmarksBloc>(
      tester.element(find.byType(BookmarksView)),
    );
    await tester.tap(find.text(first.title));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    expect(bloc.isClosed, isTrue);
    navigation.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
    verify(() => repository.getBookmarks()).called(1);
    verifyNoMoreInteractions(repository);
  });
}
