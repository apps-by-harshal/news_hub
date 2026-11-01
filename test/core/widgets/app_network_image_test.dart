import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/widgets/app_network_image.dart';

import '../../helpers/mocks.dart';
import '../../helpers/network_image_helpers.dart';
import '../../helpers/pump_app.dart';

void main() {
  const String imageUrl = 'https://example.com/image.jpg';
  const Size tileSize = Size(96, 72);

  late MockCacheManager cacheManager;

  // AppNetworkImage takes no cache manager (lib/ never imports
  // flutter_cache_manager), so each test replaces the package's static
  // default with a fresh mock before anything reads it.
  setUp(() {
    cacheManager = MockCacheManager();
    CachedNetworkImageProvider.defaultCacheManager = cacheManager;
  });

  tearDown(clearImageCache);

  Future<void> pumpImage(WidgetTester tester, {required String? url}) {
    return tester.pumpApp(
      Center(
        child: AppNetworkImage(
          url: url,
          width: tileSize.width,
          height: tileSize.height,
        ),
      ),
    );
  }

  group('AppNetworkImage without a URL', () {
    testWidgets('null → sized fallback, no network image', (
      WidgetTester tester,
    ) async {
      await pumpImage(tester, url: null);

      expect(find.byKey(AppNetworkImage.fallbackKey), findsOneWidget);
      expect(find.byIcon(Icons.newspaper), findsOneWidget);
      expect(tester.getSize(find.byKey(AppNetworkImage.fallbackKey)), tileSize);
      expect(find.byType(CachedNetworkImage), findsNothing);
      verifyZeroInteractions(cacheManager);
    });

    testWidgets('blank → sized fallback, no network image', (
      WidgetTester tester,
    ) async {
      await pumpImage(tester, url: '   ');

      expect(find.byKey(AppNetworkImage.fallbackKey), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      verifyZeroInteractions(cacheManager);
    });
  });

  group('AppNetworkImage with a URL', () {
    testWidgets('builds a CachedNetworkImage on the default cache manager', (
      WidgetTester tester,
    ) async {
      stubImageNeverLoads(cacheManager);

      await pumpImage(tester, url: imageUrl);

      final CachedNetworkImage image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, imageUrl);
      expect(image.width, tileSize.width);
      expect(image.height, tileSize.height);
      expect(image.fit, BoxFit.cover);
      expect(image.cacheManager, isNull);
    });

    testWidgets('shows the sized placeholder while loading', (
      WidgetTester tester,
    ) async {
      stubImageNeverLoads(cacheManager);

      await pumpImage(tester, url: imageUrl);
      await tester.pump();

      expect(find.byKey(AppNetworkImage.placeholderKey), findsOneWidget);
      expect(
        tester.getSize(find.byKey(AppNetworkImage.placeholderKey)),
        tileSize,
      );
      expect(find.byKey(AppNetworkImage.fallbackKey), findsNothing);
      verify(
        () => cacheManager.getFileStream(
          imageUrl,
          key: null,
          headers: null,
          withProgress: true,
        ),
      ).called(1);
    });

    testWidgets('shows the sized fallback when loading fails', (
      WidgetTester tester,
    ) async {
      stubImageFailsToLoad(cacheManager);

      await pumpImage(tester, url: imageUrl);
      await tester.pumpAndSettle();

      expect(find.byKey(AppNetworkImage.fallbackKey), findsOneWidget);
      expect(find.byIcon(Icons.newspaper), findsOneWidget);
      expect(tester.getSize(find.byKey(AppNetworkImage.fallbackKey)), tileSize);
      expect(find.byKey(AppNetworkImage.placeholderKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('trims the URL before loading it', (WidgetTester tester) async {
      stubImageNeverLoads(cacheManager);

      await pumpImage(tester, url: '  $imageUrl  ');

      final CachedNetworkImage image = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(image.imageUrl, imageUrl);
    });
  });
}
