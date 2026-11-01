// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_adapters.dart';

// **************************************************************************
// AdaptersGenerator
// **************************************************************************

class ArticleLocalModelAdapter extends TypeAdapter<ArticleLocalModel> {
  @override
  final typeId = 0;

  @override
  ArticleLocalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArticleLocalModel(
      url: fields[0] as String,
      title: fields[1] as String,
      sourceId: fields[2] as String?,
      sourceName: fields[3] as String,
      publishedAt: fields[4] as DateTime,
      author: fields[5] as String?,
      description: fields[6] as String?,
      content: fields[7] as String?,
      imageUrl: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ArticleLocalModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.url)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.sourceId)
      ..writeByte(3)
      ..write(obj.sourceName)
      ..writeByte(4)
      ..write(obj.publishedAt)
      ..writeByte(5)
      ..write(obj.author)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.content)
      ..writeByte(8)
      ..write(obj.imageUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArticleLocalModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedArticlesLocalModelAdapter
    extends TypeAdapter<CachedArticlesLocalModel> {
  @override
  final typeId = 1;

  @override
  CachedArticlesLocalModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedArticlesLocalModel(
      articles: (fields[0] as List).cast<ArticleLocalModel>(),
    );
  }

  @override
  void write(BinaryWriter writer, CachedArticlesLocalModel obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.articles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedArticlesLocalModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
