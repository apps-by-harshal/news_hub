import 'package:hive_ce/hive_ce.dart';

/// The app's local Hive database.
///
/// Feature-agnostic: it knows no box names, models or adapters. Features own
/// their box names and open their boxes through [openBox] (the news_feed
/// local data source). The adapters to register are passed to the
/// implementation by the composition root (`core/di/`), because the
/// generated `lib/hive_registrar.g.dart` imports feature models.
///
/// Errors from Hive itself (`HiveError`, which is an `Error`, not an
/// `Exception`) pass through unchanged; data sources wrap their calls in
/// `guardStorageCall` to turn them into `CacheException`.
abstract interface class LocalDatabase {
  /// Initialises Hive and registers the app's adapters.
  ///
  /// Safe to call more than once, including concurrently: the work runs
  /// once and every caller awaits the same result. If it fails, the error
  /// is passed on and the next call tries again.
  Future<void> init();

  /// Opens the box called [name] with values of type [T], or returns it
  /// when it is already open.
  ///
  /// Throws a [StateError] when [init] has not completed. A box must always
  /// be opened with the same [T]; Hive rejects a second type with a
  /// `HiveError`.
  Future<Box<T>> openBox<T>(String name);

  /// Closes every open box.
  ///
  /// Later [openBox] calls open boxes again; [init] does not run again
  /// (Hive keeps its home directory and registered adapters).
  Future<void> close();
}
