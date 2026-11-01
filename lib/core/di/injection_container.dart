import 'package:get_it/get_it.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/core_module.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/features/news_feed/news_feed_injection.dart';

/// The app-wide service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency into [container], or into the global [getIt]
/// when no container is given, then initialises local storage.
///
/// Registers the core module first, then each feature module (they read core
/// services from the container). As the composition root, `core/di/` is the
/// only part of `core/` that may import feature modules (CLAUDE.md §3.1).
///
/// Completes once `LocalDatabase.init()` has completed (Hive set up and
/// adapters registered, Step 17a); a storage failure is passed on to the
/// caller (`bootstrap.dart`, Step 23). [localDatabase] replaces the real
/// database in tests, which have no Flutter engine for `Hive.initFlutter`.
/// [AppConfig.fromEnvironment] is called by `main.dart`, never here.
Future<void> initDependencies({
  required AppConfig config,
  GetIt? container,
  LocalDatabase? localDatabase,
}) async {
  final GetIt target = container ?? getIt;
  registerCoreModule(target, config: config, localDatabase: localDatabase);
  registerNewsFeedModule(target);
  await target<LocalDatabase>().init();
}
