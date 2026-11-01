import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:news_hub/features/news_feed/data/models/article_source_model.dart';

void main() {
  group('ArticleSourceModel.fromJson', () {
    test('reads id and name', () {
      final ArticleSourceModel model = ArticleSourceModel.fromJson(
        <String, Object?>{'id': 'bbc-news', 'name': 'BBC News'},
      );

      expect(model, const ArticleSourceModel(id: 'bbc-news', name: 'BBC News'));
    });

    test('keeps a null id', () {
      final ArticleSourceModel model = ArticleSourceModel.fromJson(
        <String, Object?>{'id': null, 'name': 'Tech Daily'},
      );

      expect(model, const ArticleSourceModel(id: null, name: 'Tech Daily'));
    });

    test('reads missing keys as null', () {
      final ArticleSourceModel model = ArticleSourceModel.fromJson(
        <String, Object?>{},
      );

      expect(model, const ArticleSourceModel(id: null, name: null));
    });

    test('throws CheckedFromJsonException naming "name" when it is not a '
        'String', () {
      expect(
        () => ArticleSourceModel.fromJson(<String, Object?>{
          'id': 'bbc-news',
          'name': 42,
        }),
        throwsA(
          isA<CheckedFromJsonException>()
              .having((CheckedFromJsonException e) => e.key, 'key', 'name')
              .having(
                (CheckedFromJsonException e) => e.className,
                'className',
                'ArticleSourceModel',
              ),
        ),
      );
    });

    test('throws CheckedFromJsonException naming "id" when it is not a '
        'String', () {
      expect(
        () => ArticleSourceModel.fromJson(<String, Object?>{
          'id': 7,
          'name': 'BBC News',
        }),
        throwsA(
          isA<CheckedFromJsonException>()
              .having((CheckedFromJsonException e) => e.key, 'key', 'id')
              .having(
                (CheckedFromJsonException e) => e.className,
                'className',
                'ArticleSourceModel',
              ),
        ),
      );
    });
  });

  group('ArticleSourceModel equality', () {
    test('props are [id, name] in declaration order', () {
      final ArticleSourceModel model = ArticleSourceModel.fromJson(
        <String, Object?>{'id': 'bbc-news', 'name': 'BBC News'},
      );

      expect(model.props, <Object?>['bbc-news', 'BBC News']);
    });

    test('models with different names are not equal', () {
      final ArticleSourceModel first = ArticleSourceModel.fromJson(
        <String, Object?>{'id': 'bbc-news', 'name': 'BBC News'},
      );
      final ArticleSourceModel second = ArticleSourceModel.fromJson(
        <String, Object?>{'id': 'bbc-news', 'name': 'BBC World'},
      );

      expect(first, isNot(second));
    });
  });
}
