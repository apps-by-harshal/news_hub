import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:get_it/get_it.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/features/news_feed/data/api/news_api_service.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source_impl.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source_impl.dart';
import 'package:news_hub/features/news_feed/data/repositories/news_repository_impl.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_top_headlines.dart';
import 'package:news_hub/features/news_feed/domain/usecases/search_articles.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';

/// Registers the news_feed feature's dependencies in [getIt].
///
/// Needs the core module first (`registerCoreModule`): [Dio], [CacheOptions],
/// [LocalDatabase], [NetworkInfo] and [AppLogger] are read from [getIt].
/// Called by `initDependencies`, the composition root (CLAUDE.md §3.1).
///
/// Everything is a lazy singleton: nothing is built until first requested,
/// and building it touches neither the network nor local storage. Blocs are
/// not registered: each page creates its bloc in a `BlocProvider` from these
/// use cases (D19).
void registerNewsFeedModule(GetIt getIt) {
  getIt
    // Data
    ..registerLazySingleton<NewsApiService>(() => NewsApiService(getIt<Dio>()))
    ..registerLazySingleton<NewsRemoteDataSource>(
      () => NewsRemoteDataSourceImpl(
        apiService: getIt<NewsApiService>(),
        cacheOptions: getIt<CacheOptions>(),
      ),
    )
    ..registerLazySingleton<NewsLocalDataSource>(
      () => NewsLocalDataSourceImpl(localDatabase: getIt<LocalDatabase>()),
    )
    ..registerLazySingleton<NewsRepository>(
      () => NewsRepositoryImpl(
        remoteDataSource: getIt<NewsRemoteDataSource>(),
        localDataSource: getIt<NewsLocalDataSource>(),
        networkInfo: getIt<NetworkInfo>(),
        logger: getIt<AppLogger>(),
      ),
    )
    // Domain
    ..registerLazySingleton<GetTopHeadlines>(
      () => GetTopHeadlines(repository: getIt<NewsRepository>()),
    )
    ..registerLazySingleton<SearchArticles>(
      () => SearchArticles(repository: getIt<NewsRepository>()),
    )
    ..registerLazySingleton<ToggleBookmark>(
      () => ToggleBookmark(repository: getIt<NewsRepository>()),
    )
    ..registerLazySingleton<GetBookmarkStatus>(
      () => GetBookmarkStatus(repository: getIt<NewsRepository>()),
    );
}
