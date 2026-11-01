import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_state.dart';

import '../../../../../fixtures/article_builders.dart';
import '../../../../../helpers/mocks.dart';

// The use cases are `final` classes, so the bloc gets real `GetBookmarkStatus`
// and `ToggleBookmark` on a mocked repository. Stubs use exact
// values (the article compares by value); every test ends with
// `verifyNoMoreInteractions`.

const String urlA = 'https://example.com/a';

const failures.Failure cacheFailure = failures.CacheFailure('disk');
const failures.Failure unexpectedFailure = failures.UnexpectedFailure('bug');

Result<bool> successOf(bool value) => Success<bool>(value);

Result<bool> failureOf(failures.Failure failure) => Failure<bool>(failure);

/// A ready state for the article at [urlA].
ArticleDetailReady ready({
  required bool isBookmarked,
  bool isToggling = false,
  failures.Failure? toggleFailure,
}) => ArticleDetailReady(
  article: buildArticle(urlA),
  isBookmarked: isBookmarked,
  isToggling: isToggling,
  toggleFailure: toggleFailure,
);

/// Lets pending microtasks run: delivered events, handlers up to their
/// `await`, and emits after a completed future.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late MockNewsRepository repository;

  setUp(() {
    repository = MockNewsRepository();
  });

  ArticleDetailBloc buildBloc() => ArticleDetailBloc(
    getBookmarkStatus: GetBookmarkStatus(repository: repository),
    toggleBookmark: ToggleBookmark(repository: repository),
    article: buildArticle(urlA),
  );

  When<Future<Result<bool>>> whenStatus() =>
      when(() => repository.isBookmarked(urlA));

  When<Future<Result<bool>>> whenToggle() =>
      when(() => repository.toggleBookmark(buildArticle(urlA)));

  test('starts as ArticleDetailLoading for its article', () async {
    final ArticleDetailBloc bloc = buildBloc();

    expect(bloc.state, ArticleDetailLoading(article: buildArticle(urlA)));

    await bloc.close();
    verifyNoMoreInteractions(repository);
  });

  group('ArticleDetailStarted', () {
    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'shows a bookmarked article as bookmarked',
      setUp: () => whenStatus().thenAnswer((_) async => successOf(true)),
      build: buildBloc,
      act: (ArticleDetailBloc bloc) => bloc.add(const ArticleDetailStarted()),
      expect: () => <ArticleDetailState>[ready(isBookmarked: true)],
      verify: (_) {
        verify(() => repository.isBookmarked(urlA)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'shows an article without a bookmark as not bookmarked',
      setUp: () => whenStatus().thenAnswer((_) async => successOf(false)),
      build: buildBloc,
      act: (ArticleDetailBloc bloc) => bloc.add(const ArticleDetailStarted()),
      expect: () => <ArticleDetailState>[ready(isBookmarked: false)],
      verify: (_) {
        verify(() => repository.isBookmarked(urlA)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'emits ArticleDetailStatusFailure when the status cannot be read',
      setUp: () =>
          whenStatus().thenAnswer((_) async => failureOf(cacheFailure)),
      build: buildBloc,
      act: (ArticleDetailBloc bloc) => bloc.add(const ArticleDetailStarted()),
      expect: () => <ArticleDetailState>[
        ArticleDetailStatusFailure(
          article: buildArticle(urlA),
          failure: cacheFailure,
        ),
      ],
      verify: (_) {
        verify(() => repository.isBookmarked(urlA)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'after a failure it shows loading again, then the status',
      setUp: () => whenStatus().thenAnswer((_) async => successOf(true)),
      build: buildBloc,
      seed: () => ArticleDetailStatusFailure(
        article: buildArticle(urlA),
        failure: cacheFailure,
      ),
      act: (ArticleDetailBloc bloc) => bloc.add(const ArticleDetailStarted()),
      expect: () => <ArticleDetailState>[
        ArticleDetailLoading(article: buildArticle(urlA)),
        ready(isBookmarked: true),
      ],
      verify: (_) {
        verify(() => repository.isBookmarked(urlA)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'is ignored once the status is known',
      build: buildBloc,
      seed: () => ready(isBookmarked: true),
      act: (ArticleDetailBloc bloc) => bloc.add(const ArticleDetailStarted()),
      expect: () => <ArticleDetailState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    final Completer<Result<bool>> status = Completer<Result<bool>>();

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'two quick Started events read the status once',
      setUp: () => whenStatus().thenAnswer((_) => status.future),
      build: buildBloc,
      act: (ArticleDetailBloc bloc) async {
        bloc
          ..add(const ArticleDetailStarted())
          ..add(const ArticleDetailStarted());
        await flush();
        status.complete(successOf(false));
        await flush();
      },
      expect: () => <ArticleDetailState>[ready(isBookmarked: false)],
      verify: (_) {
        verify(() => repository.isBookmarked(urlA)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('ArticleDetailBookmarkToggled', () {
    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'bookmarks an article that is not bookmarked',
      setUp: () => whenToggle().thenAnswer((_) async => successOf(true)),
      build: buildBloc,
      seed: () => ready(isBookmarked: false),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: false, isToggling: true),
        ready(isBookmarked: true),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'removes the bookmark of a bookmarked article',
      setUp: () => whenToggle().thenAnswer((_) async => successOf(false)),
      build: buildBloc,
      seed: () => ready(isBookmarked: true),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: true, isToggling: true),
        ready(isBookmarked: false),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'a failure keeps the shown status and sets toggleFailure',
      setUp: () =>
          whenToggle().thenAnswer((_) async => failureOf(cacheFailure)),
      build: buildBloc,
      seed: () => ready(isBookmarked: true),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: true, isToggling: true),
        ready(isBookmarked: true, toggleFailure: cacheFailure),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'clears the previous failure when it starts, so the same failure again '
      'is a new state',
      setUp: () =>
          whenToggle().thenAnswer((_) async => failureOf(cacheFailure)),
      build: buildBloc,
      seed: () => ready(isBookmarked: false, toggleFailure: cacheFailure),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: false, isToggling: true),
        ready(isBookmarked: false, toggleFailure: cacheFailure),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'a success clears a failure from an earlier toggle',
      setUp: () => whenToggle().thenAnswer((_) async => successOf(true)),
      build: buildBloc,
      seed: () => ready(isBookmarked: false, toggleFailure: unexpectedFailure),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: false, isToggling: true),
        ready(isBookmarked: true),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'is ignored while a toggle is in progress',
      build: buildBloc,
      seed: () => ready(isBookmarked: false, isToggling: true),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'is ignored while the status is loading',
      build: buildBloc,
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'is ignored when the status could not be read',
      build: buildBloc,
      seed: () => ArticleDetailStatusFailure(
        article: buildArticle(urlA),
        failure: cacheFailure,
      ),
      act: (ArticleDetailBloc bloc) =>
          bloc.add(const ArticleDetailBookmarkToggled()),
      expect: () => <ArticleDetailState>[],
      verify: (_) => verifyNoMoreInteractions(repository),
    );

    final Completer<Result<bool>> toggle = Completer<Result<bool>>();

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'two quick taps toggle once',
      setUp: () => whenToggle().thenAnswer((_) => toggle.future),
      build: buildBloc,
      seed: () => ready(isBookmarked: false),
      act: (ArticleDetailBloc bloc) async {
        bloc
          ..add(const ArticleDetailBookmarkToggled())
          ..add(const ArticleDetailBookmarkToggled());
        await flush();
        toggle.complete(successOf(true));
        await flush();
      },
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: false, isToggling: true),
        ready(isBookmarked: true),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ArticleDetailBloc, ArticleDetailState>(
      'a tap after a finished toggle toggles again',
      setUp: () {
        final List<Result<bool>> answers = <Result<bool>>[
          successOf(true),
          successOf(false),
        ];
        whenToggle().thenAnswer((_) async => answers.removeAt(0));
      },
      build: buildBloc,
      seed: () => ready(isBookmarked: false),
      act: (ArticleDetailBloc bloc) async {
        bloc.add(const ArticleDetailBookmarkToggled());
        await flush();
        bloc.add(const ArticleDetailBookmarkToggled());
        await flush();
      },
      expect: () => <ArticleDetailState>[
        ready(isBookmarked: false, isToggling: true),
        ready(isBookmarked: true),
        ready(isBookmarked: true, isToggling: true),
        ready(isBookmarked: false),
      ],
      verify: (_) {
        verify(() => repository.toggleBookmark(buildArticle(urlA))).called(2);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  test('closing while a toggle is pending emits nothing more', () async {
    final Completer<Result<bool>> pending = Completer<Result<bool>>();
    whenStatus().thenAnswer((_) async => successOf(false));
    whenToggle().thenAnswer((_) => pending.future);
    final ArticleDetailBloc bloc = buildBloc();

    bloc.add(const ArticleDetailStarted());
    await flush();
    bloc.add(const ArticleDetailBookmarkToggled());
    await flush();
    await bloc.close();
    pending.complete(successOf(true));
    await flush();

    expect(bloc.state, ready(isBookmarked: false, isToggling: true));
    verify(() => repository.isBookmarked(urlA)).called(1);
    verify(() => repository.toggleBookmark(buildArticle(urlA))).called(1);
    verifyNoMoreInteractions(repository);
  });
}
