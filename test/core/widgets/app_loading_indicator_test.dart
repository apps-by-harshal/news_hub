import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/widgets/app_loading_indicator.dart';

import '../../helpers/pump_app.dart';

// The indicator animates forever, so these tests never call
// `pumpAndSettle` (it would time out); one frame from `pumpApp` is enough.

void main() {
  group('AppLoadingIndicator', () {
    testWidgets('shows a circular progress indicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpApp(const AppLoadingIndicator());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('centres the indicator', (WidgetTester tester) async {
      await tester.pumpApp(const AppLoadingIndicator());

      expect(
        find.ancestor(
          of: find.byType(CircularProgressIndicator),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is announced as "Loading" to screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpApp(const AppLoadingIndicator());

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });
  });
}
