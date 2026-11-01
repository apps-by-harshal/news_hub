import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:news_hub/app.dart';
import 'package:news_hub/core/theme/app_theme.dart';

/// A one-route router, so `App` is tested without the feature pages (they
/// need get_it; `app_router_test.dart` covers them).
GoRouter _buildTestRouter() {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const Text('start page');
        },
      ),
    ],
  );
}

void main() {
  group('App', () {
    testWidgets('configures MaterialApp.router with the title, themes and '
        'the given router', (WidgetTester tester) async {
      final GoRouter router = _buildTestRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(App(router: router));

      final MaterialApp app = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(app.title, 'News Hub');
      expect(app.theme, AppTheme.light);
      expect(app.darkTheme, AppTheme.dark);
      expect(app.themeMode, ThemeMode.system);
      expect(app.routerConfig, same(router));
    });

    testWidgets('shows the router start page in the light theme', (
      WidgetTester tester,
    ) async {
      final GoRouter router = _buildTestRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(App(router: router));

      expect(find.text('start page'), findsOneWidget);
      final ThemeData theme = Theme.of(tester.element(find.text('start page')));
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme, AppTheme.light.colorScheme);
    });

    testWidgets('follows the platform into the dark theme', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final GoRouter router = _buildTestRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(App(router: router));

      final ThemeData theme = Theme.of(tester.element(find.text('start page')));
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme, AppTheme.dark.colorScheme);
    });
  });
}
