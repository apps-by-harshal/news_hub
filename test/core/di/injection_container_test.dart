import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';

import '../../helpers/mocks.dart';

void main() {
  late AppConfig config;
  late MockLocalDatabase localDatabase;

  setUp(() {
    config = AppConfig.fromMap(const <String, String>{
      'FLAVOR': 'dev',
      'API_BASE_URL': 'https://newsapi.org/v2',
      'API_KEY': 'test-api-key',
      'ENABLE_HTTP_LOGGING': 'false',
      'LOG_LEVEL': 'debug',
    });
    // A fake database: the real one would call Hive.initFlutter, which needs
    // the Flutter engine and path_provider.
    localDatabase = MockLocalDatabase();
    when(() => localDatabase.init()).thenAnswer((_) async {});
  });

  group('initDependencies', () {
    group('with an explicit container', () {
      late GetIt container;

      setUp(() {
        container = GetIt.asNewInstance();
      });

      tearDown(() async {
        await container.reset();
      });

      test('registers the core module into the given container '
          'and leaves the global getIt untouched', () async {
        await initDependencies(
          config: config,
          container: container,
          localDatabase: localDatabase,
        );

        expect(container.isRegistered<Dio>(), isTrue);
        expect(container<LocalDatabase>(), same(localDatabase));
        expect(getIt.isRegistered<Dio>(), isFalse);
      });

      test(
        'also registers the news_feed module into the given container',
        () async {
          await initDependencies(
            config: config,
            container: container,
            localDatabase: localDatabase,
          );

          expect(container.isRegistered<NewsRepository>(), isTrue);
          expect(container<GetTopHeadlines>(), isA<GetTopHeadlines>());
          expect(getIt.isRegistered<GetTopHeadlines>(), isFalse);
        },
      );

      test('initialises the local database once', () async {
        await initDependencies(
          config: config,
          container: container,
          localDatabase: localDatabase,
        );

        verify(() => localDatabase.init()).called(1);
        verifyNoMoreInteractions(localDatabase);
      });

      test('does not complete before LocalDatabase.init() completes', () async {
        final Completer<void> gate = Completer<void>();
        when(() => localDatabase.init()).thenAnswer((_) => gate.future);
        bool done = false;

        final Future<void> initializing = initDependencies(
          config: config,
          container: container,
          localDatabase: localDatabase,
        ).whenComplete(() => done = true);
        await pumpEventQueue();
        expect(done, isFalse);

        gate.complete();
        await initializing;
        expect(done, isTrue);
      });

      test('passes a LocalDatabase.init() failure on', () async {
        when(() => localDatabase.init())
            .thenAnswer((_) => Future<void>.error(StateError('disk full')));

        await expectLater(
          initDependencies(
            config: config,
            container: container,
            localDatabase: localDatabase,
          ),
          throwsStateError,
        );
      });
    });

    group('without a container', () {
      tearDown(() async {
        await getIt.reset();
      });

      test('registers the core module into the global getIt', () async {
        await initDependencies(config: config, localDatabase: localDatabase);

        expect(identical(getIt, GetIt.instance), isTrue);
        expect(getIt.isRegistered<Dio>(), isTrue);
        expect(getIt<LocalDatabase>(), same(localDatabase));
        verify(() => localDatabase.init()).called(1);
      });
    });
  });
}
