import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/core_module.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/features/news_feed/data/api/news_api_service.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source_impl.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source_impl.dart';
import 'package:news_hub/features/news_feed/data/repositories/news_repository_impl.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmarks.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/domain/usecases/search_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';
import 'package:news_hub/features/news_feed/news_feed_injection.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_bloc.dart';

import '../../helpers/mocks.dart';

void main() {
  late GetIt container;
  late MockLocalDatabase localDatabase;

  setUp(() {
    container = GetIt.asNewInstance();
    // A fake database: nothing here may call init() or openBox().
    localDatabase = MockLocalDatabase();
    registerCoreModule(
      container,
      config: AppConfig.fromMap(const <String, String>{
        'FLAVOR': 'dev',
        'API_BASE_URL': 'https://newsapi.org/v2',
        'API_KEY': 'test-api-key',
        'ENABLE_HTTP_LOGGING': 'false',
        'LOG_LEVEL': 'debug',
      }),
      localDatabase: localDatabase,
    );
  });

  tearDown(() async {
    await container.reset();
  });

  /// Reads [T] twice and expects the very same object (a lazy singleton).
  void expectSameOnEveryRead<T extends Object>() {
    final T first = container<T>();
    final T second = container<T>();
    expect(first, same(second), reason: '$T should be a singleton');
  }

  group('registerNewsFeedModule', () {
    test('registers each data contract as its implementation', () {
      registerNewsFeedModule(container);

      expect(container<NewsApiService>(), isA<NewsApiService>());
      expect(
        container<NewsRemoteDataSource>(),
        isA<NewsRemoteDataSourceImpl>(),
      );
      expect(container<NewsLocalDataSource>(), isA<NewsLocalDataSourceImpl>());
      expect(container<NewsRepository>(), isA<NewsRepositoryImpl>());
    });

    test('registers the five use cases', () {
      registerNewsFeedModule(container);

      expect(container<GetTopHeadlines>(), isA<GetTopHeadlines>());
      expect(container<SearchArticles>(), isA<SearchArticles>());
      expect(container<ToggleBookmark>(), isA<ToggleBookmark>());
      expect(container<GetBookmarkStatus>(), isA<GetBookmarkStatus>());
      expect(container<GetBookmarks>(), isA<GetBookmarks>());
    });

    test('returns the same instance on every read', () {
      registerNewsFeedModule(container);

      expectSameOnEveryRead<NewsApiService>();
      expectSameOnEveryRead<NewsRemoteDataSource>();
      expectSameOnEveryRead<NewsLocalDataSource>();
      expectSameOnEveryRead<NewsRepository>();
      expectSameOnEveryRead<GetTopHeadlines>();
      expectSameOnEveryRead<SearchArticles>();
      expectSameOnEveryRead<ToggleBookmark>();
      expectSameOnEveryRead<GetBookmarkStatus>();
      expectSameOnEveryRead<GetBookmarks>();
    });

    test('registers no bloc (blocs live in BlocProvider)', () {
      registerNewsFeedModule(container);

      expect(container.isRegistered<NewsFeedBloc>(), isFalse);
      expect(container.isRegistered<ArticleDetailBloc>(), isFalse);
    });

    test('registers into the given container only', () {
      registerNewsFeedModule(container);

      expect(container.isRegistered<NewsRepository>(), isTrue);
      expect(getIt.isRegistered<NewsRepository>(), isFalse);
      expect(getIt.isRegistered<GetTopHeadlines>(), isFalse);
    });

    test('resolving the whole graph never touches local storage', () {
      registerNewsFeedModule(container);

      // Each use case pulls in the repository and both data sources.
      final List<Object> resolved = <Object>[
        container<GetTopHeadlines>(),
        container<SearchArticles>(),
        container<ToggleBookmark>(),
        container<GetBookmarkStatus>(),
        container<GetBookmarks>(),
      ];

      expect(resolved, hasLength(5));
      verifyNoMoreInteractions(localDatabase);
    });
  });
}
