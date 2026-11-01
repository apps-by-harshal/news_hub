import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/core/storage/local_database.dart';

/// [LocalDatabase] over a [HiveInterface] (Step 17a).
///
/// The two setup steps are injected so `core/` stays feature-agnostic and
/// tests need no Flutter engine:
/// - `initialize` points Hive at its home directory. The app passes the
///   `Hive.initFlutter` tear-off (hive_ce_flutter); tests run
///   `Hive.init(tempDir.path)`.
/// - `registerAdapters` registers the generated adapters. The app passes the
///   `Hive.registerAdapters` tear-off from `lib/hive_registrar.g.dart`; only
///   the composition root (`core/di/`) imports it.
///
/// Both run once per instance: Hive rejects an adapter registered twice, so
/// [close] only closes boxes and never resets [init].
final class LocalDatabaseImpl implements LocalDatabase {
  /// Creates the database. Nothing touches Hive until [init] is called.
  LocalDatabaseImpl({
    required this._hive,
    required this._initialize,
    required this._registerAdapters,
  });

  final HiveInterface _hive;
  final Future<void> Function() _initialize;
  final void Function() _registerAdapters;

  /// The running or completed setup, shared by every [init] caller; reset to
  /// `null` when it fails so the next [init] tries again.
  Future<void>? _initializing;

  /// `true` once setup has completed; [openBox] is allowed only then.
  bool _isInitialized = false;

  @override
  Future<void> init() async {
    final Future<void> initializing = _initializing ??= _setUp();
    try {
      await initializing;
    } catch (_) {
      // Only the first failing caller resets, never a newer attempt.
      if (identical(_initializing, initializing)) _initializing = null;
      rethrow;
    }
  }

  Future<void> _setUp() async {
    await _initialize();
    _registerAdapters();
    _isInitialized = true;
  }

  @override
  Future<Box<T>> openBox<T>(String name) async {
    if (!_isInitialized) {
      throw StateError(
        'LocalDatabase.init() must complete before openBox("$name").',
      );
    }
    return _hive.openBox<T>(name);
  }

  @override
  Future<void> close() => _hive.close();
}
