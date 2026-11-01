import 'package:news_hub/core/error/failures.dart' as failures;

/// User-facing copy for a domain failure (D9).
///
/// The UI chooses its text by failure *type* and never shows
/// `failures.Failure.message`, which is diagnostic text for logs. The switch
/// is exhaustive over the sealed `Failure` family, so a new failure type
/// fails to compile here until it gets its own copy.
///
/// The copy is plain English for now; it moves to localised strings when
/// l10n is planned.
extension FailureMessage on failures.Failure {
  /// A short sentence the UI can show for this failure.
  String get userMessage => switch (this) {
    failures.ServerFailure() =>
      'The news service is having trouble. Please try again later.',
    failures.UnauthorizedFailure() =>
      "The news service rejected the app's API key.",
    failures.NetworkFailure() =>
      "You're offline. Check your connection and try again.",
    failures.CacheFailure() => "Couldn't read or save data on this device.",
    failures.UnexpectedFailure() => 'Something went wrong. Please try again.',
  };
}
