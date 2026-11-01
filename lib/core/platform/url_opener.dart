/// Opens a web link outside the app's own screens.
///
/// The article detail screen uses it for "Open full article". It is pure
/// Dart with no imports, so widget and page tests replace it with a mocktail
/// mock and never reach the `url_launcher` plugin.
///
/// The implementation, `UrlOpenerImpl`, hands the link to the platform's
/// default handler: an in-app browser tab on Android and iOS, a new tab on
/// the web.
abstract interface class UrlOpener {
  /// Opens [url].
  ///
  /// Completes with `true` when the platform took the link and `false` when
  /// it could not be opened (no app to handle it, or a platform error). Never
  /// throws, so a caller only has to tell the user that it failed.
  Future<bool> open(Uri url);
}
