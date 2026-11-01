// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'article_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArticleModel _$ArticleModelFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ArticleModel', json, ($checkedConvert) {
      final val = ArticleModel(
        source: $checkedConvert(
          'source',
          (v) => v == null
              ? null
              : ArticleSourceModel.fromJson(v as Map<String, dynamic>),
        ),
        author: $checkedConvert('author', (v) => v as String?),
        title: $checkedConvert('title', (v) => v as String?),
        description: $checkedConvert('description', (v) => v as String?),
        url: $checkedConvert('url', (v) => v as String?),
        urlToImage: $checkedConvert('urlToImage', (v) => v as String?),
        publishedAt: $checkedConvert('publishedAt', (v) => v as String?),
        content: $checkedConvert('content', (v) => v as String?),
      );
      return val;
    });
