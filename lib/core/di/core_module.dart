import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/logging/app_logger_impl.dart';
import 'package:news_hub/core/network/cache/http_cache_config.dart';
import 'package:news_hub/core/network/dio_client.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/network/network_info_impl.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/core/storage/local_database_impl.dart';
import 'package:news_hub/hive_registrar.g.dart';

/// Registers the shared, feature-agnostic services in [getIt].
///
/// [config] is read once in `main.dart` with `AppConfig.fromEnvironment()`
/// and passed in through `bootstrap` and `initDependencies`, so this function
/// never reads compile-time values and stays testable.
///
/// Everything except [config] is a lazy singleton: nothing is built until it
/// is first requested, and every lookup returns the same instance.
///
/// [LocalDatabase] (Step 17a) is a lazy [LocalDatabaseImpl] over [Hive],
/// given the `Hive.initFlutter` and `Hive.registerAdapters` tear-offs, so
/// nothing touches Hive until `initDependencies` awaits `init()`. As the
/// composition root, `core/di/` is the only part of `core/` that may import
/// the generated `hive_registrar.g.dart` (CLAUDE.md §3.1). Tests pass
/// [localDatabase] to register a fake instead.
void registerCoreModule(
  GetIt getIt, {
  required AppConfig config,
  LocalDatabase? localDatabase,
}) {
  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<AppLogger>(
      () => AppLoggerImpl(minLevel: config.logLevel),
    )
    ..registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(
        connectivity: Connectivity(),
        logger: getIt<AppLogger>(),
      ),
    )
    ..registerLazySingleton<CacheOptions>(createHttpCacheOptions)
    ..registerLazySingleton<Dio>(
      () => createDioClient(
        config: getIt<AppConfig>(),
        logger: getIt<AppLogger>(),
        cacheOptions: getIt<CacheOptions>(),
      ),
    );

  if (localDatabase != null) {
    getIt.registerSingleton<LocalDatabase>(localDatabase);
  } else {
    getIt.registerLazySingleton<LocalDatabase>(
      () => LocalDatabaseImpl(
        hive: Hive,
        initialize: Hive.initFlutter,
        registerAdapters: Hive.registerAdapters,
      ),
    );
  }
}
