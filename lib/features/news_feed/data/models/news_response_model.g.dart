// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_response_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NewsResponseModel _$NewsResponseModelFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NewsResponseModel', json, ($checkedConvert) {
      final val = NewsResponseModel(
        status: $checkedConvert('status', (v) => v as String?),
        totalResults: $checkedConvert(
          'totalResults',
          (v) => (v as num?)?.toInt(),
        ),
        articles: $checkedConvert(
          'articles',
          (v) => (v as List<dynamic>?)
              ?.map((e) => ArticleModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });
