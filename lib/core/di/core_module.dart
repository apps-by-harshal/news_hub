import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl;

import '../../hive_registrar.g.dart';
import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../logging/app_logger_impl.dart';
import '../network/cache/http_cache_config.dart';
import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../network/network_info_impl.dart';
import '../platform/url_opener.dart';
import '../platform/url_opener_impl.dart';
import '../storage/local_database.dart';
import '../storage/local_database_impl.dart';

/// Registers the shared, feature-agnostic services in [getIt].
///
/// [config] is read once in `main.dart` with `AppConfig.fromEnvironment()`
/// and passed in through `bootstrap` and `initDependencies`, so this function
/// never reads compile-time values and stays testable.
///
/// Everything except [config] is a lazy singleton: nothing is built until it
/// is first requested, and every lookup returns the same instance.
///
/// [LocalDatabase] is a lazy [LocalDatabaseImpl] over [Hive],
/// given the `Hive.initFlutter` and `Hive.registerAdapters` tear-offs, so
/// nothing touches Hive until `initDependencies` awaits `init()`. As the
/// composition root, `core/di/` is the only part of `core/` that may import
/// the generated `hive_registrar.g.dart`. Tests pass
/// [localDatabase] to register a fake instead.
///
/// [UrlOpener] is a lazy [UrlOpenerImpl] given url_launcher's
/// `launchUrl` tear-off, so resolving it never touches the plugin; the link
/// opens only when `open` is called.
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
    )
    ..registerLazySingleton<UrlOpener>(
      () => UrlOpenerImpl(launch: launchUrl, logger: getIt<AppLogger>()),
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
