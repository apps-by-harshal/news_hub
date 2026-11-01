import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/theme/app_theme.dart';
import 'package:news_hub/startup_error_app.dart';

void main() {
  const String storageMessage =
      "Couldn't open storage on this device. Please restart the app.";

  group('StartupErrorApp', () {
    testWidgets('shows the storage message with no Retry button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const StartupErrorApp());

      expect(find.text(storageMessage), findsOneWidget);
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is a MaterialApp titled News Hub with the app themes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const StartupErrorApp());

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.title, 'News Hub');
      expect(app.theme, AppTheme.light);
      expect(app.darkTheme, AppTheme.dark);
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets('passes a key built at run time through', (
      WidgetTester tester,
    ) async {
      // Built at run time on purpose: a const-only constructor shows as an
      // uncovered line in the full-suite run.
      final Key key = UniqueKey();

      await tester.pumpWidget(StartupErrorApp(key: key));

      expect(find.byKey(key), findsOneWidget);
      expect(find.text(storageMessage), findsOneWidget);
    });
  });
}
