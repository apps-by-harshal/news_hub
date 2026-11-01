import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/core/error/exceptions.dart';

/// Runs one local-storage [call] and maps Hive failures to [CacheException]
/// (Step 17a), the storage counterpart of `guardApiCall` (D10).
///
/// - `HiveError` (an `Error`, not an `Exception`: closed box, missing
///   adapter, corrupt file, …) →
///   `CacheException('Local storage failed: …')`.
/// - [TypeError] (a stored value of an unexpected type) →
///   `CacheException('Unexpected stored value: …')`.
/// - [AppException] and anything else are rethrown unchanged; the
///   repository's catch-all turns those into `UnexpectedFailure`.
///
/// Stack traces are kept. Messages never contain stored values, only Hive's
/// own diagnostic text. Local data sources wrap every Hive call in this.
Future<T> guardStorageCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on HiveError catch (error, stackTrace) {
    Error.throwWithStackTrace(
      CacheException('Local storage failed: ${error.message}'),
      stackTrace,
    );
  } on TypeError catch (error, stackTrace) {
    Error.throwWithStackTrace(
      CacheException('Unexpected stored value: $error'),
      stackTrace,
    );
  }
}
