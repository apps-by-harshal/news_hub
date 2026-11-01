import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

void main() {
  group('NewsCategory', () {
    test('has exactly the seven NewsAPI categories', () {
      expect(NewsCategory.values, hasLength(7));
    });

    test('lists the categories in chip display order, general first', () {
      expect(NewsCategory.values, const <NewsCategory>[
        NewsCategory.general,
        NewsCategory.business,
        NewsCategory.entertainment,
        NewsCategory.health,
        NewsCategory.science,
        NewsCategory.sports,
        NewsCategory.technology,
      ]);
    });
  });
}
