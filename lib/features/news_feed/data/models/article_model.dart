import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:news_hub/features/news_feed/data/models/article_source_model.dart';

part 'article_model.g.dart';

/// One raw article from a NewsAPI response.
///
/// Mirrors the API exactly: every field is nullable, `urlToImage` keeps its
/// API name, and `publishedAt` stays the raw string. The article mapper
/// (`article_mapper.dart`) validates, renames and normalises (D11).
///
/// Generated with `checked: true`, so a field of the wrong type throws a
/// [CheckedFromJsonException] naming the key; `guardApiCall` turns it into
/// a `ParsingException` (D10).
@JsonSerializable(checked: true, createToJson: false)
final class ArticleModel extends Equatable {
  const ArticleModel({
    required this.source,
    required this.author,
    required this.title,
    required this.description,
    required this.url,
    required this.urlToImage,
    required this.publishedAt,
    required this.content,
  });

  factory ArticleModel.fromJson(Map<String, Object?> json) =>
      _$ArticleModelFromJson(json);

  final ArticleSourceModel? source;
  final String? author;
  final String? title;
  final String? description;
  final String? url;
  final String? urlToImage;
  final String? publishedAt;
  final String? content;

  @override
  List<Object?> get props => <Object?>[
    source,
    author,
    title,
    description,
    url,
    urlToImage,
    publishedAt,
    content,
  ];
}
