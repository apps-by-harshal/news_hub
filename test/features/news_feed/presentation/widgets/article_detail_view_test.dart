import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/widgets/app_network_image.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_state.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/article_detail_view.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

const String _url = 'https://example.com/markets-rally';
const String _title = 'Markets rally as rates hold steady';
const String _author = 'Jane Doe';
const String _description =
    'Stocks rose after the central bank kept rates unchanged.';
const String _content =
    'Shares climbed across every sector on Thursday as investors cheered.';
const String _imageUrl = 'https://example.com/markets-rally.jpg';

/// Built from a local wall-clock time, so it reads `Oct 30, 2026` in every
/// time zone.
final DateTime _publishedAt = DateTime(2026, 10, 30, 12).toUtc();
const String _meta = 'Reuters · Oct 30, 2026';

const String _openLabel = 'Open full article';
const String _openFailureCopy = "Couldn't open the article.";

const String _cacheCopy =
    "Couldn't update the bookmark. Couldn't read or save data on this device.";
const String _networkCopy =
    "Couldn't update the bookmark. "
    "You're offline. Check your connection and try again.";

Article _buildArticle({
  String? author = _author,
  String? description = _description,
  String? content = _content,
  String? imageUrl = _imageUrl,
}) {
  return Article(
    url: _url,
    title: _title,
    source: const ArticleSource(id: 'reuters', name: 'Reuters'),
    publishedAt: _publishedAt,
    author: author,
    description: description,
    content: content,
    imageUrl: imageUrl,
  );
}

void main() {
  late MockArticleDetailBloc bloc;
  late StreamController<ArticleDetailState> controller;
  late Article article;

  /// Every URL the view asked to open, in order.
  late List<Uri> openedUrls;

  /// What the next open answers; `true` unless a test changes it.
  late Future<bool> Function() openAnswer;

  /// The `onOpenArticle` callback given to the view: records, then answers.
  Future<bool> openArticle(Uri url) {
    openedUrls.add(url);
    return openAnswer();
  }

  setUpAll(() {
    registerFallbackValue(const ArticleDetailStarted());
    useNeverLoadingImages();
  });

  setUp(() {
    bloc = MockArticleDetailBloc();
    controller = StreamController<ArticleDetailState>.broadcast();
    article = _buildArticle();
    openedUrls = <Uri>[];
    openAnswer = () async => true;
  });

  tearDown(() async {
    clearImageCache();
    if (!controller.isClosed) {
      await controller.close();
    }
  });

  Future<void> pumpView(
    WidgetTester tester,
    ArticleDetailState initialState,
  ) async {
    whenListen(bloc, controller.stream, initialState: initialState);
    await tester.pumpApp(
      BlocProvider<ArticleDetailBloc>.value(
        value: bloc,
        child: ArticleDetailView(onOpenArticle: openArticle),
      ),
    );
  }

  Future<void> emitState(WidgetTester tester, ArticleDetailState state) async {
    controller.add(state);
    await tester.pump();
  }

  IconButton iconButton(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  /// The "Open full article" button, whatever its concrete button class.
  ButtonStyleButton openButton(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(_openLabel),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is ButtonStyleButton,
          ),
        ),
      );

  /// Scrolls the button into view (it sits below the article text), taps it
  /// and lets the open finish.
  Future<void> tapOpen(WidgetTester tester) async {
    await tester.ensureVisible(find.text(_openLabel));
    await tester.pump();
    await tester.tap(find.text(_openLabel));
    await tester.pump();
  }

  testWidgets('passes its key to the widget tree', (WidgetTester tester) async {
    // Built at run time (not `const`), so the constructor itself runs: the
    // full-suite coverage run misses a constructor only ever called as
    // `const` (Step 22-3).
    final Key key = UniqueKey();
    whenListen(
      bloc,
      controller.stream,
      initialState: ArticleDetailLoading(article: article),
    );

    await tester.pumpApp(
      BlocProvider<ArticleDetailBloc>.value(
        value: bloc,
        child: ArticleDetailView(key: key, onOpenArticle: openArticle),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
    expect(find.byType(ArticleDetailView), findsOneWidget);
  });

  group('content', () {
    testWidgets(
      'shows the title, source and date, byline, description, content '
      'and the URL as selectable text',
      (WidgetTester tester) async {
        await pumpView(
          tester,
          ArticleDetailReady(article: article, isBookmarked: false),
        );

        expect(find.text(_title), findsOneWidget);
        expect(find.text(_meta), findsOneWidget);
        expect(find.text('By $_author'), findsOneWidget);
        expect(find.text(_description), findsOneWidget);
        expect(find.text(_content), findsOneWidget);
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          _url,
        );
      },
    );

    testWidgets('leaves out missing optional fields and shows the image '
        'fallback', (WidgetTester tester) async {
      article = _buildArticle(
        author: null,
        description: null,
        content: null,
        imageUrl: null,
      );
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_meta), findsOneWidget);
      expect(find.textContaining('By '), findsNothing);
      expect(find.text(_description), findsNothing);
      expect(find.text(_content), findsNothing);
      expect(find.byKey(AppNetworkImage.fallbackKey), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        _url,
      );
    });

    testWidgets('shows the image at full width in 16:9 while it loads', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, ArticleDetailLoading(article: article));

      expect(find.byKey(AppNetworkImage.placeholderKey), findsOneWidget);
      expect(
        tester.widget<AppNetworkImage>(find.byType(AppNetworkImage)).url,
        _imageUrl,
      );
      expect(
        tester.getSize(find.byType(AppNetworkImage)),
        const Size(800, 450),
      );
    });

    testWidgets('scrolls long content on a small screen without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final String longContent = List<String>.filled(300, 'word').join(' ');
      article = _buildArticle(content: longContent);

      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byType(SelectableText));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(SelectableText)).bottom,
        lessThanOrEqualTo(480),
      );
    });
  });

  group('bookmark action', () {
    testWidgets('is disabled while the status loads', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, ArticleDetailLoading(article: article));

      final IconButton button = iconButton(tester, Icons.bookmark_border);
      expect(button.onPressed, isNull);
      expect(button.tooltip, 'Bookmark');
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('adds a bookmark when the article is not bookmarked', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      final IconButton button = iconButton(tester, Icons.bookmark_border);
      expect(button.onPressed, isNotNull);
      expect(button.tooltip, 'Add bookmark');
      expect(find.byIcon(Icons.bookmark), findsNothing);

      await tester.tap(find.byTooltip('Add bookmark'));

      verify(() => bloc.add(const ArticleDetailBookmarkToggled())).called(1);
    });

    testWidgets('removes the bookmark when the article is bookmarked', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: true),
      );

      final IconButton button = iconButton(tester, Icons.bookmark);
      expect(button.onPressed, isNotNull);
      expect(button.tooltip, 'Remove bookmark');
      expect(find.byIcon(Icons.bookmark_border), findsNothing);

      await tester.tap(find.byTooltip('Remove bookmark'));

      verify(() => bloc.add(const ArticleDetailBookmarkToggled())).called(1);
    });

    testWidgets('is disabled while a toggle is in progress', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: true,
          isToggling: true,
        ),
      );

      final IconButton button = iconButton(tester, Icons.bookmark);
      expect(button.onPressed, isNull);
      expect(button.tooltip, 'Remove bookmark');

      await tester.tap(find.widgetWithIcon(IconButton, Icons.bookmark));

      verifyNever(() => bloc.add(any()));
    });

    testWidgets('offers a Retry when the status could not be read', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailStatusFailure(
          article: article,
          failure: const failures.CacheFailure('Hive box locked'),
        ),
      );

      final IconButton bookmark = iconButton(tester, Icons.bookmark_border);
      expect(bookmark.onPressed, isNull);
      expect(bookmark.tooltip, 'Bookmark');
      final IconButton retry = iconButton(tester, Icons.refresh);
      expect(retry.onPressed, isNotNull);
      expect(retry.tooltip, 'Retry loading bookmark');
      expect(find.textContaining('Hive box locked'), findsNothing);

      await tester.tap(find.byTooltip('Retry loading bookmark'));

      verify(() => bloc.add(const ArticleDetailStarted())).called(1);
    });

    testWidgets('follows the bloc from loading to ready', (
      WidgetTester tester,
    ) async {
      await pumpView(tester, ArticleDetailLoading(article: article));

      await emitState(
        tester,
        ArticleDetailReady(article: article, isBookmarked: true),
      );

      final IconButton button = iconButton(tester, Icons.bookmark);
      expect(button.onPressed, isNotNull);
      expect(button.tooltip, 'Remove bookmark');
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
    });

    testWidgets('follows a retry from status failure through loading to '
        'ready, with no snackbar', (WidgetTester tester) async {
      await pumpView(
        tester,
        ArticleDetailStatusFailure(
          article: article,
          failure: const failures.CacheFailure('Hive box locked'),
        ),
      );
      expect(find.byTooltip('Retry loading bookmark'), findsOneWidget);

      await emitState(tester, ArticleDetailLoading(article: article));

      expect(find.byTooltip('Retry loading bookmark'), findsNothing);
      expect(iconButton(tester, Icons.bookmark_border).onPressed, isNull);

      await emitState(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );
      await tester.pump(const Duration(milliseconds: 750));

      final IconButton button = iconButton(tester, Icons.bookmark_border);
      expect(button.onPressed, isNotNull);
      expect(button.tooltip, 'Add bookmark');
      expect(find.byTooltip('Retry loading bookmark'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('open full article', () {
    testWidgets('opens the article URL once from the Open full article '
        'button', (WidgetTester tester) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      expect(find.text(_openLabel), findsOneWidget);
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);
      expect(openButton(tester).onPressed, isNotNull);

      await tapOpen(tester);

      expect(openedUrls, <Uri>[Uri.parse(_url)]);
      verifyNever(() => bloc.add(any()));
    });

    testWidgets('shows a snackbar when the article could not be opened', (
      WidgetTester tester,
    ) async {
      openAnswer = () async => false;
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      await tapOpen(tester);
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text(_openFailureCopy), findsOneWidget);
      expect(openButton(tester).onPressed, isNotNull);
    });

    testWidgets('shows no snackbar when the article opened', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      await tapOpen(tester);
      await tester.pump(const Duration(milliseconds: 750));

      expect(openedUrls, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('is disabled while the article is opening and enabled again '
        'after', (WidgetTester tester) async {
      final Completer<bool> pending = Completer<bool>();
      openAnswer = () => pending.future;
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      await tapOpen(tester);

      expect(openButton(tester).onPressed, isNull);
      await tester.tap(find.text(_openLabel));
      await tester.pump();
      expect(openedUrls, hasLength(1));

      pending.complete(true);
      await tester.pump();

      expect(openButton(tester).onPressed, isNotNull);
      expect(openedUrls, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('throws nothing when the view is removed while opening', (
      WidgetTester tester,
    ) async {
      final Completer<bool> pending = Completer<bool>();
      openAnswer = () => pending.future;
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );
      await tapOpen(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(false);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(openedUrls, hasLength(1));
    });
  });

  group('toggle failure', () {
    testWidgets('shows a snackbar with the user message, never the '
        'diagnostic message', (WidgetTester tester) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      await emitState(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: false,
          toggleFailure: const failures.CacheFailure('Hive box locked'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text(_cacheCopy), findsOneWidget);
      expect(find.textContaining('Hive box locked'), findsNothing);
    });

    testWidgets('shows no snackbar for a failure already in the first state', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: false,
          toggleFailure: const failures.CacheFailure('Hive box locked'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('replaces the snackbar when a later toggle fails', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );
      await emitState(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: false,
          toggleFailure: const failures.NetworkFailure('timeout'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text(_networkCopy), findsOneWidget);

      await emitState(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: false,
          isToggling: true,
        ),
      );
      await emitState(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: false,
          toggleFailure: const failures.CacheFailure('Hive box locked'),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(_networkCopy), findsNothing);
      expect(find.text(_cacheCopy), findsOneWidget);
    });

    testWidgets('shows no snackbar when a toggle succeeds', (
      WidgetTester tester,
    ) async {
      await pumpView(
        tester,
        ArticleDetailReady(article: article, isBookmarked: false),
      );

      await emitState(
        tester,
        ArticleDetailReady(
          article: article,
          isBookmarked: false,
          isToggling: true,
        ),
      );
      await emitState(
        tester,
        ArticleDetailReady(article: article, isBookmarked: true),
      );
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
