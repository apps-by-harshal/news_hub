import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/platform/url_opener.dart';
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/pages/article_detail_page.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/article_detail_view.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  late MockNewsRepository repository;
  late MockUrlOpener opener;
  late Article article;

  setUpAll(useNeverLoadingImages);

  setUp(() {
    repository = MockNewsRepository();
    opener = MockUrlOpener();
    article = buildArticle('https://example.com/detail');
    getIt
      ..registerSingleton<UrlOpener>(opener)
      ..registerFactory<GetBookmarkStatus>(
        () => GetBookmarkStatus(repository: repository),
      )
      ..registerFactory<ToggleBookmark>(
        () => ToggleBookmark(repository: repository),
      );
  });

  tearDown(() async {
    clearImageCache();
    await getIt.reset();
  });

  /// The repository call behind `GetBookmarkStatus` for [article].
  Future<Result<bool>> status() => repository.isBookmarked(article.url);

  /// The repository call behind `ToggleBookmark` for [article].
  Future<Result<bool>> toggle() => repository.toggleBookmark(article);

  IconButton iconButton(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  testWidgets('creates its bloc for the article and reads the bookmark '
      'status', (WidgetTester tester) async {
    final Completer<Result<bool>> pending = Completer<Result<bool>>();
    when(status).thenAnswer((_) => pending.future);

    await tester.pumpApp(ArticleDetailPage(article: article));

    expect(find.byType(ArticleDetailView), findsOneWidget);
    expect(find.text(article.title), findsOneWidget);
    expect(iconButton(tester, Icons.bookmark_border).onPressed, isNull);

    pending.complete(const Success<bool>(true));
    await tester.pump();

    final IconButton button = iconButton(tester, Icons.bookmark);
    expect(button.onPressed, isNotNull);
    expect(button.tooltip, 'Remove bookmark');
    verify(status).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('toggles the bookmark through the real use case', (
    WidgetTester tester,
  ) async {
    when(status).thenAnswer((_) async => const Success<bool>(false));
    when(toggle).thenAnswer((_) async => const Success<bool>(true));

    await tester.pumpApp(ArticleDetailPage(article: article));
    await tester.pump();
    await tester.tap(find.byTooltip('Add bookmark'));
    await tester.pump();

    final IconButton button = iconButton(tester, Icons.bookmark);
    expect(button.onPressed, isNotNull);
    expect(button.tooltip, 'Remove bookmark');
    verifyInOrder(<void Function()>[status, toggle]);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('Retry reads the status again after it could not be read', (
    WidgetTester tester,
  ) async {
    final List<Result<bool>> answers = <Result<bool>>[
      const Failure<bool>(failures.CacheFailure('Hive box locked')),
      const Success<bool>(false),
    ];
    when(status).thenAnswer((_) async => answers.removeAt(0));

    await tester.pumpApp(ArticleDetailPage(article: article));
    await tester.pump();

    expect(iconButton(tester, Icons.bookmark_border).onPressed, isNull);
    await tester.tap(find.byTooltip('Retry loading bookmark'));
    await tester.pump();

    expect(find.byTooltip('Retry loading bookmark'), findsNothing);
    final IconButton button = iconButton(tester, Icons.bookmark_border);
    expect(button.onPressed, isNotNull);
    expect(button.tooltip, 'Add bookmark');
    verify(status).called(2);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('opens the article URL through the app UrlOpener', (
    WidgetTester tester,
  ) async {
    final Uri url = Uri.parse(article.url);
    when(status).thenAnswer((_) async => const Success<bool>(false));
    when(() => opener.open(url)).thenAnswer((_) async => true);

    await tester.pumpApp(ArticleDetailPage(article: article));
    await tester.pump();
    await tester.ensureVisible(find.text('Open full article'));
    await tester.pump();
    await tester.tap(find.text('Open full article'));
    await tester.pump();

    verify(() => opener.open(url)).called(1);
    verifyNoMoreInteractions(opener);
    expect(find.byType(SnackBar), findsNothing);
    verify(status).called(1);
    verifyNoMoreInteractions(repository);
  });

  testWidgets('closes its bloc when removed, even with a request pending', (
    WidgetTester tester,
  ) async {
    final Completer<Result<bool>> pending = Completer<Result<bool>>();
    when(status).thenAnswer((_) => pending.future);

    await tester.pumpApp(ArticleDetailPage(article: article));
    final ArticleDetailBloc bloc = BlocProvider.of<ArticleDetailBloc>(
      tester.element(find.byType(ArticleDetailView)),
    );
    expect(bloc.isClosed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(const Success<bool>(true));
    await tester.pump();

    expect(bloc.isClosed, isTrue);
    expect(tester.takeException(), isNull);
    verify(status).called(1);
    verifyNoMoreInteractions(repository);
  });
}
