import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'article_source_model.g.dart';

/// The raw `source` object of a NewsAPI article.
///
/// Mirrors the API exactly: every field is nullable and nothing is
/// validated here. The article mapper (`article_mapper.dart`) decides
/// whether the article is usable (D11).
///
/// Generated with `checked: true`, so a field of the wrong type throws a
/// [CheckedFromJsonException] naming the key; `guardApiCall` turns it into
/// a `ParsingException` (D10).
@JsonSerializable(checked: true, createToJson: false)
final class ArticleSourceModel extends Equatable {
  const ArticleSourceModel({required this.id, required this.name});

  factory ArticleSourceModel.fromJson(Map<String, Object?> json) =>
      _$ArticleSourceModelFromJson(json);

  final String? id;
  final String? name;

  @override
  List<Object?> get props => <Object?>[id, name];
}
