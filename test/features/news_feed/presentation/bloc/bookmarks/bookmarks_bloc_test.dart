import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_state.dart';

import '../../../../../fixtures/article_builders.dart';
import '../../../../../helpers/mocks.dart';

const String _urlA = 'https://example.com/bookmarks/a';
const String _urlB = 'https://example.com/bookmarks/b';

const failures.Failure _cacheFailure = failures.CacheFailure('box closed');
const failures.Failure _unexpectedFailure = failures.UnexpectedFailure('boom');

/// Builds a fresh list on every call.
List<Article> _articles(List<String> urls) => urls.map(buildArticle).toList();

/// `Result` values are built through functions.
Result<List<Article>> _success(List<Article> articles) {
  return Success<List<Article>>(articles);
}

Result<List<Article>> _failure(failures.Failure failure) {
  return Failure<List<Article>>(failure);
}

void main() {
  late MockNewsRepository repository;

  setUp(() {
    repository = MockNewsRepository();
  });

  /// The real use case on the mocked repository (use cases are final
  /// classes).
  BookmarksBloc buildBloc() {
    return BookmarksBloc(getBookmarks: GetBookmarks(repository: repository));
  }

  void stubBookmarks(Result<List<Article>> result) {
    when(() => repository.getBookmarks()).thenAnswer((_) async => result);
  }

  /// Every test that reaches the repository reads it exactly [times] times
  /// and does nothing else with it.
  void verifyReads(int times) {
    if (times > 0) {
      verify(() => repository.getBookmarks()).called(times);
    }
    verifyNoMoreInteractions(repository);
  }

  test('starts in BookmarksLoading', () async {
    final BookmarksBloc bloc = buildBloc();

    expect(bloc.state, const BookmarksLoading());
    await bloc.close();
    verifyReads(0);
  });

  group('BookmarksStarted', () {
    blocTest<BookmarksBloc, BookmarksState>(
      'emits the bookmarks, newest first as the repository returns them',
      setUp: () => stubBookmarks(_success(_articles(<String>[_urlB, _urlA]))),
      build: buildBloc,
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksStarted()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(articles: _articles(<String>[_urlB, _urlA])),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'emits an empty list when nothing is bookmarked',
      setUp: () => stubBookmarks(_success(<Article>[])),
      build: buildBloc,
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksStarted()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(articles: const <Article>[]),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'emits BookmarksFailure when the bookmarks cannot be read',
      setUp: () => stubBookmarks(_failure(_cacheFailure)),
      build: buildBloc,
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksStarted()),
      expect: () => <BookmarksState>[const BookmarksFailure(_cacheFailure)],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'is ignored once the bookmarks are loaded',
      build: buildBloc,
      seed: () => BookmarksLoaded(articles: _articles(<String>[_urlA])),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksStarted()),
      expect: () => <BookmarksState>[],
      verify: (BookmarksBloc _) => verifyReads(0),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'is ignored after a failure (Retry is BookmarksRefreshed)',
      build: buildBloc,
      seed: () => const BookmarksFailure(_cacheFailure),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksStarted()),
      expect: () => <BookmarksState>[],
      verify: (BookmarksBloc _) => verifyReads(0),
    );

    group('droppable', () {
      late Completer<Result<List<Article>>> pending;

      blocTest<BookmarksBloc, BookmarksState>(
        'a second Started while the first is loading reads only once',
        setUp: () {
          pending = Completer<Result<List<Article>>>();
          when(() => repository.getBookmarks())
              .thenAnswer((_) => pending.future);
        },
        build: buildBloc,
        act: (BookmarksBloc bloc) async {
          bloc
            ..add(const BookmarksStarted())
            ..add(const BookmarksStarted());
          await Future<void>.delayed(Duration.zero);
          pending.complete(_success(_articles(<String>[_urlA])));
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => <BookmarksState>[
          BookmarksLoaded(articles: _articles(<String>[_urlA])),
        ],
        verify: (BookmarksBloc _) => verifyReads(1),
      );
    });
  });

  group('BookmarksRefreshed from BookmarksLoaded', () {
    blocTest<BookmarksBloc, BookmarksState>(
      'replaces the list with the newly read one',
      setUp: () => stubBookmarks(_success(_articles(<String>[_urlB, _urlA]))),
      build: buildBloc,
      seed: () => BookmarksLoaded(articles: _articles(<String>[_urlA])),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(articles: _articles(<String>[_urlB, _urlA])),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'emits an empty list when the last bookmark was removed',
      setUp: () => stubBookmarks(_success(<Article>[])),
      build: buildBloc,
      seed: () => BookmarksLoaded(articles: _articles(<String>[_urlA])),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(articles: const <Article>[]),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'emits nothing when the list did not change',
      setUp: () => stubBookmarks(_success(_articles(<String>[_urlA]))),
      build: buildBloc,
      seed: () => BookmarksLoaded(articles: _articles(<String>[_urlA])),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'keeps the list and sets refreshFailure when the read fails',
      setUp: () => stubBookmarks(_failure(_cacheFailure)),
      build: buildBloc,
      seed: () => BookmarksLoaded(articles: _articles(<String>[_urlA])),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(
          articles: _articles(<String>[_urlA]),
          refreshFailure: _cacheFailure,
        ),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'clears an old refreshFailure when it starts, then shows the new list',
      setUp: () => stubBookmarks(_success(_articles(<String>[_urlB]))),
      build: buildBloc,
      seed: () => BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
        refreshFailure: _unexpectedFailure,
      ),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(articles: _articles(<String>[_urlA])),
        BookmarksLoaded(articles: _articles(<String>[_urlB])),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'the same failure twice still emits it again (cleared in between)',
      setUp: () => stubBookmarks(_failure(_cacheFailure)),
      build: buildBloc,
      seed: () => BookmarksLoaded(
        articles: _articles(<String>[_urlA]),
        refreshFailure: _cacheFailure,
      ),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        BookmarksLoaded(articles: _articles(<String>[_urlA])),
        BookmarksLoaded(
          articles: _articles(<String>[_urlA]),
          refreshFailure: _cacheFailure,
        ),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );
  });

  group('BookmarksRefreshed from BookmarksFailure (Retry)', () {
    blocTest<BookmarksBloc, BookmarksState>(
      'emits BookmarksLoading, then the bookmarks',
      setUp: () => stubBookmarks(_success(_articles(<String>[_urlA]))),
      build: buildBloc,
      seed: () => const BookmarksFailure(_cacheFailure),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        const BookmarksLoading(),
        BookmarksLoaded(articles: _articles(<String>[_urlA])),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    blocTest<BookmarksBloc, BookmarksState>(
      'emits BookmarksLoading, then the new failure',
      setUp: () => stubBookmarks(_failure(_unexpectedFailure)),
      build: buildBloc,
      seed: () => const BookmarksFailure(_cacheFailure),
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[
        const BookmarksLoading(),
        const BookmarksFailure(_unexpectedFailure),
      ],
      verify: (BookmarksBloc _) => verifyReads(1),
    );

    group('droppable', () {
      late Completer<Result<List<Article>>> pending;

      blocTest<BookmarksBloc, BookmarksState>(
        'a second Retry while the first is loading is dropped, and the '
        'first still finishes (never stuck in BookmarksLoading)',
        setUp: () {
          pending = Completer<Result<List<Article>>>();
          when(() => repository.getBookmarks())
              .thenAnswer((_) => pending.future);
        },
        build: buildBloc,
        seed: () => const BookmarksFailure(_cacheFailure),
        act: (BookmarksBloc bloc) async {
          bloc.add(const BookmarksRefreshed());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const BookmarksRefreshed());
          await Future<void>.delayed(Duration.zero);
          pending.complete(_success(_articles(<String>[_urlA])));
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => <BookmarksState>[
          const BookmarksLoading(),
          BookmarksLoaded(articles: _articles(<String>[_urlA])),
        ],
        verify: (BookmarksBloc _) => verifyReads(1),
      );
    });
  });

  group('BookmarksRefreshed in BookmarksLoading', () {
    blocTest<BookmarksBloc, BookmarksState>(
      'is ignored before the screen has started',
      build: buildBloc,
      act: (BookmarksBloc bloc) => bloc.add(const BookmarksRefreshed()),
      expect: () => <BookmarksState>[],
      verify: (BookmarksBloc _) => verifyReads(0),
    );

    group('while Started is loading', () {
      late Completer<Result<List<Article>>> pending;

      blocTest<BookmarksBloc, BookmarksState>(
        'is ignored, and the first load still finishes',
        setUp: () {
          pending = Completer<Result<List<Article>>>();
          when(() => repository.getBookmarks())
              .thenAnswer((_) => pending.future);
        },
        build: buildBloc,
        act: (BookmarksBloc bloc) async {
          bloc.add(const BookmarksStarted());
          await Future<void>.delayed(Duration.zero);
          bloc.add(const BookmarksRefreshed());
          await Future<void>.delayed(Duration.zero);
          pending.complete(_success(_articles(<String>[_urlA])));
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => <BookmarksState>[
          BookmarksLoaded(articles: _articles(<String>[_urlA])),
        ],
        verify: (BookmarksBloc _) => verifyReads(1),
      );
    });
  });

  test('closing while a read is pending emits nothing more and throws '
      'nothing', () async {
    final Completer<Result<List<Article>>> pending =
        Completer<Result<List<Article>>>();
    when(() => repository.getBookmarks()).thenAnswer((_) => pending.future);
    final BookmarksBloc bloc = buildBloc();
    final List<BookmarksState> states = <BookmarksState>[];
    final StreamSubscription<BookmarksState> subscription = bloc.stream.listen(
      states.add,
    );

    bloc.add(const BookmarksStarted());
    await Future<void>.delayed(Duration.zero);
    // bloc 9.2.1's close() cancels the running handler's emitter and doesn't
    // wait for the read, so the read completes only after the bloc is closed
    // (the same pattern as the other bloc tests).
    await bloc.close();
    pending.complete(_success(_articles(<String>[_urlA])));
    await Future<void>.delayed(Duration.zero);

    expect(states, isEmpty);
    expect(bloc.state, const BookmarksLoading());
    expect(bloc.isClosed, isTrue);
    await subscription.cancel();
    verifyReads(1);
  });
}
