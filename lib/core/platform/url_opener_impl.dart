import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/platform/url_opener.dart';

/// The launcher [UrlOpenerImpl] calls: url_launcher's `launchUrl` in the app
/// (its optional named parameters keep their defaults, so the platform
/// chooses how to open the link), a recording fake in tests.
typedef LaunchUrlFunction = Future<bool> Function(Uri url);

/// [UrlOpener] backed by url_launcher (Step 25, D24).
///
/// `core_module.dart` registers it with the `launchUrl` tear-off, so nothing
/// reaches the plugin until a link is opened (the same pattern as
/// `LocalDatabaseImpl` with `Hive.initFlutter`).
///
/// url_launcher reports failure in two ways: iOS returns `false` (no app for
/// the link, or the in-app browser closed before loading), while Android and
/// both platforms' error paths throw a `PlatformException`; an invalid
/// in-app request throws `ArgumentError` before anything starts. All of them
/// become `false` with one warning, so [open] never throws. The URL itself
/// is never logged.
final class UrlOpenerImpl implements UrlOpener {
  /// Creates an opener that calls `launch` and reports failures to `logger`.
  const UrlOpenerImpl({required this._launch, required this._logger});

  final LaunchUrlFunction _launch;
  final AppLogger _logger;

  @override
  Future<bool> open(Uri url) async {
    try {
      final bool opened = await _launch(url);
      if (!opened) {
        _logger.warning('No app could open the link');
      }
      return opened;
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Opening a link failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
