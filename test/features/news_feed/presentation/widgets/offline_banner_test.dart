import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/offline_banner.dart';

import '../../../../helpers/pump_app.dart';

/// The banner copy, spelled out so a wording change fails here.
const String _message = "You're offline. Showing saved headlines.";

void main() {
  group('OfflineBanner', () {
    testWidgets('shows the offline icon and message', (
      WidgetTester tester,
    ) async {
      await tester.pumpApp(const OfflineBanner());

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text(_message), findsOneWidget);
    });

    testWidgets('is announced as a live region labelled by its message only', (
      WidgetTester tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(const OfflineBanner());

      expect(
        tester.getSemantics(find.text(_message)),
        isSemantics(label: _message, isLiveRegion: true),
      );

      handle.dispose();
    });

    testWidgets('wraps on a narrow screen with large text without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: OfflineBanner(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_message), findsOneWidget);
    });
  });
}
