import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/platform/url_opener.dart';
import 'package:news_hub/core/platform/url_opener_impl.dart';

import '../../helpers/mocks.dart';

const String _link = 'https://example.com/markets-rally';

/// A launcher that records every URL it is given and answers with [_answer].
final class _RecordingLauncher {
  _RecordingLauncher(this._answer);

  final Future<bool> Function() _answer;

  final List<Uri> calls = <Uri>[];

  Future<bool> call(Uri url) {
    calls.add(url);
    return _answer();
  }
}

void main() {
  late MockAppLogger logger;
  late Uri url;

  setUp(() {
    logger = MockAppLogger();
    url = Uri.parse(_link);
  });

  UrlOpener buildOpener(_RecordingLauncher launcher) =>
      UrlOpenerImpl(launch: launcher.call, logger: logger);

  test('passes the exact URL to the launcher and returns true', () async {
    final _RecordingLauncher launcher = _RecordingLauncher(() async => true);

    final bool opened = await buildOpener(launcher).open(url);

    expect(opened, isTrue);
    expect(launcher.calls, <Uri>[Uri.parse(_link)]);
    verifyNoMoreInteractions(logger);
  });

  test(
    'returns false and logs a warning when no app opened the link',
    () async {
      final _RecordingLauncher launcher = _RecordingLauncher(() async => false);

      final bool opened = await buildOpener(launcher).open(url);

      expect(opened, isFalse);
      expect(launcher.calls, <Uri>[Uri.parse(_link)]);
      verify(() => logger.warning('No app could open the link')).called(1);
      verifyNoMoreInteractions(logger);
    },
  );

  test('returns false and logs the platform error with its stack trace when '
      'the launch fails', () async {
    // What url_launcher_android throws when no app can handle the link.
    final PlatformException error = PlatformException(
      code: 'ACTIVITY_NOT_FOUND',
      message: 'No Activity found to handle intent',
    );
    final StackTrace stackTrace = StackTrace.current;
    final _RecordingLauncher launcher = _RecordingLauncher(
      () => Future<bool>.error(error, stackTrace),
    );

    final bool opened = await buildOpener(launcher).open(url);

    expect(opened, isFalse);
    expect(launcher.calls, <Uri>[Uri.parse(_link)]);
    verify(
      () => logger.warning(
        'Opening a link failed',
        error: error,
        stackTrace: stackTrace,
      ),
    ).called(1);
    verifyNoMoreInteractions(logger);
  });

  test(
    'returns false and logs an Error thrown before the launch starts',
    () async {
      // url_launcher throws ArgumentError synchronously for an in-app mode with
      // a non-http(s) URL; any Error from the launcher must not escape.
      final ArgumentError error = ArgumentError.value(url, 'url', 'Bad link');
      final _RecordingLauncher launcher = _RecordingLauncher(() => throw error);

      final bool opened = await buildOpener(launcher).open(url);

      expect(opened, isFalse);
      expect(launcher.calls, <Uri>[Uri.parse(_link)]);
      verify(
        () => logger.warning(
          'Opening a link failed',
          error: error,
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
      verifyNoMoreInteractions(logger);
    },
  );
}
