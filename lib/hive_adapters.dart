// The app's single list of Hive types (D1), at app level on purpose:
// `core/` stays feature-agnostic (CLAUDE.md §3.1), and hive_ce_generator
// writes `hive_registrar.g.dart` next to this file, so both live in `lib/`.
// Only the composition root (`core/di/`) imports the registrar.
//
// Generated from this file (all committed, D6):
// - `hive_adapters.g.dart`: one TypeAdapter per spec (part of this library).
// - `hive_adapters.g.yaml`: the schema that pins type ids and field indices.
//   Never edit or delete it: losing it renumbers types and breaks stored
//   data.
// - `hive_registrar.g.dart`: `Hive.registerAdapters()`.
//
// Type ids start at 0 (the default `firstTypeId`); hive_ce_flutter's own
// Color / TimeOfDay adapters use 200 / 201. Add new specs at the end of the
// list; never reorder or remove one without a migration.
import 'package:hive_ce/hive_ce.dart';
import 'package:news_hub/features/news_feed/data/models/article_local_model.dart';
import 'package:news_hub/features/news_feed/data/models/cached_articles_local_model.dart';

@GenerateAdapters([
  AdapterSpec<ArticleLocalModel>(),
  AdapterSpec<CachedArticlesLocalModel>(),
])
part 'hive_adapters.g.dart';
