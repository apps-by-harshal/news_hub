import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/widgets/app_error_view.dart';

import '../../helpers/pump_app.dart';

void main() {
  const String message = "You're offline. Check your connection and try again.";

  group('AppErrorView', () {
    testWidgets('shows the message and an error icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpApp(const AppErrorView(message: message));

      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows a Retry button that calls onRetry once per tap', (
      WidgetTester tester,
    ) async {
      int retries = 0;

      await tester.pumpApp(
        AppErrorView(
          message: message,
          onRetry: () {
            retries += 1;
          },
        ),
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retries, 1);
    });

    testWidgets('shows no button when onRetry is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpApp(const AppErrorView(message: message));

      expect(find.text('Retry'), findsNothing);
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('wraps a long message on a narrow screen without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final String longMessage = List<String>.filled(
        40,
        'unavailable',
      ).join(' ');

      await tester.pumpApp(AppErrorView(message: longMessage, onRetry: () {}));

      expect(find.text(longMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
