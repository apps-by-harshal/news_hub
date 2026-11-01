import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/widgets/app_network_image.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/article_source.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/article_list_tile.dart';

import '../../../../helpers/network_image_helpers.dart';
import '../../../../helpers/pump_app.dart';

const String _title = 'Markets rally as tech stocks rebound';
const String _imageUrl = 'https://example.com/images/markets.jpg';

/// `source · DateFormatter.shortDate`, spelled out. The input is built from a
/// local wall-clock time, so the date reads the same in every time zone.
const String _subtitle = 'Reuters · Oct 30, 2026';

Article _article({String title = _title, String? imageUrl = _imageUrl}) {
  return Article(
    url: 'https://example.com/articles/markets',
    title: title,
    source: const ArticleSource(id: 'reuters', name: 'Reuters'),
    publishedAt: DateTime(2026, 10, 30, 12).toUtc(),
    author: 'Jane Doe',
    description: 'Shares climbed on Friday.',
    content: 'Shares climbed on Friday after…',
    imageUrl: imageUrl,
  );
}

Future<void> _pumpTile(
  WidgetTester tester, {
  Article? article,
  VoidCallback? onTap,
}) {
  return tester.pumpApp(
    ArticleListTile(article: article ?? _article(), onTap: onTap ?? () {}),
  );
}

void main() {
  setUpAll(useNeverLoadingImages);
  tearDown(clearImageCache);

  group('ArticleListTile', () {
    testWidgets('shows the title and "source · date"', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester);

      expect(find.text(_title), findsOneWidget);
      expect(find.text(_subtitle), findsOneWidget);
    });

    testWidgets('limits the title to two lines with an ellipsis', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester);

      final Text title = tester.widget<Text>(find.text(_title));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
    });

    testWidgets('shows the article image at 96×72', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester);

      final AppNetworkImage image = tester.widget<AppNetworkImage>(
        find.byType(AppNetworkImage),
      );
      expect(image.url, _imageUrl);
      expect(image.width, 96);
      expect(image.height, 72);
      expect(tester.getSize(find.byType(AppNetworkImage)), const Size(96, 72));
    });

    testWidgets('shows the 96×72 fallback when the article has no image', (
      WidgetTester tester,
    ) async {
      await _pumpTile(tester, article: _article(imageUrl: null));

      final AppNetworkImage image = tester.widget<AppNetworkImage>(
        find.byType(AppNetworkImage),
      );
      expect(image.url, isNull);
      expect(find.byKey(AppNetworkImage.fallbackKey), findsOneWidget);
      expect(tester.getSize(find.byType(AppNetworkImage)), const Size(96, 72));
    });

    testWidgets('calls onTap once per tap', (WidgetTester tester) async {
      int taps = 0;
      await _pumpTile(tester, onTap: () => taps++);

      await tester.tap(find.text(_title));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('lays out a very long title on a narrow screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final String longTitle = List<String>.filled(40, 'headline').join(' ');

      await _pumpTile(tester, article: _article(title: longTitle));

      expect(tester.takeException(), isNull);
      expect(find.text(longTitle), findsOneWidget);
      expect(find.text(_subtitle), findsOneWidget);
    });
  });
}
