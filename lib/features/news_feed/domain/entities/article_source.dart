import 'package:equatable/equatable.dart';

/// The publisher an `Article` came from.
///
/// Pure domain value: no serialization. The data layer maps NewsAPI's
/// `source` object onto this.
final class ArticleSource extends Equatable {
  /// Creates a source. [id] is nullable because NewsAPI omits it for many
  /// publishers. [name] is always present for valid articles; the mapper
  /// drops any article without it.
  const ArticleSource({required this.id, required this.name});

  /// NewsAPI's source identifier (for example `bbc-news`), when it has one.
  final String? id;

  /// The publisher's display name.
  final String name;

  @override
  List<Object?> get props => <Object?>[id, name];
}
