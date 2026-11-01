import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:get_it/get_it.dart';

import '../../core/logging/app_logger.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/local_database.dart';
import 'data/api/news_api_service.dart';
import 'data/datasources/news_local_data_source.dart';
import 'data/datasources/news_local_data_source_impl.dart';
import 'data/datasources/news_remote_data_source.dart';
import 'data/datasources/news_remote_data_source_impl.dart';
import 'data/repositories/news_repository_impl.dart';
import 'domain/repositories/news_repository.dart';
import 'domain/usecases/get_bookmark_status.dart';
import 'domain/usecases/get_bookmarks.dart';
import 'domain/usecases/get_top_headlines.dart';
import 'domain/usecases/search_articles.dart';
import 'domain/usecases/toggle_bookmark.dart';

/// Registers the news_feed feature's dependencies in [getIt].
///
/// Needs the core module first (`registerCoreModule`): [Dio], [CacheOptions],
/// [LocalDatabase], [NetworkInfo] and [AppLogger] are read from [getIt].
/// Called by `initDependencies`, the composition root.
///
/// Everything is a lazy singleton: nothing is built until first requested,
/// and building it touches neither the network nor local storage. Blocs are
/// not registered: each page creates its bloc in a `BlocProvider` from these
/// use cases.
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
    )
    ..registerLazySingleton<GetBookmarks>(
      () => GetBookmarks(repository: getIt<NewsRepository>()),
    );
}
