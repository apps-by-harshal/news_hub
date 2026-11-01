import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'article_model.dart';

part 'news_response_model.g.dart';

/// The envelope of a NewsAPI `/top-headlines` or `/everything` response.
///
/// Mirrors the API: every field is nullable. `status` is kept for
/// diagnostics only; error responses arrive as non-2xx and are mapped by
/// `ErrorInterceptor`, so nothing checks it. The error body's `code` and
/// `message` are ignored here (unknown keys are allowed).
///
/// Generated with `checked: true`, so a field of the wrong type, including
/// a nested article field, throws a [CheckedFromJsonException] naming the
/// key; `guardApiCall` turns it into a `ParsingException`.
@JsonSerializable(checked: true, createToJson: false)
final class NewsResponseModel extends Equatable {
  const NewsResponseModel({
    required this.status,
    required this.totalResults,
    required this.articles,
  });

  factory NewsResponseModel.fromJson(Map<String, Object?> json) =>
      _$NewsResponseModelFromJson(json);

  final String? status;
  final int? totalResults;
  final List<ArticleModel>? articles;

  @override
  List<Object?> get props => <Object?>[status, totalResults, articles];
}
