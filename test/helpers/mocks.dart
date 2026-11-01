import 'package:bloc_test/bloc_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/storage/local_database.dart';
import 'package:news_hub/features/news_feed/data/api/news_api_service.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_local_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source.dart';
import 'package:news_hub/features/news_feed/domain/repositories/news_repository.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_state.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/bookmarks/bookmarks_state.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_event.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/news_feed/news_feed_state.dart';

/// Shared mocktail mocks for every abstract contract and external
/// dependency (CLAUDE.md §5). Add new mocks here as contracts appear,
/// grouped by layer and kept in alphabetical order within each group.
///
/// Fallback values for `any()` matchers are registered in each test's
/// `setUpAll`, not here, so every test states what it relies on.
///
/// Bloc mocks (Step 22) extend bloc_test's `MockBloc`, which stubs only
/// `stream` and `close()`: every test must script `state` with
/// `whenListen(bloc, stream, initialState: …)`. They can implement the
/// blocs because the blocs are `interface class`es (D19, amended Step 22).

// ---- core ----

class MockAppLogger extends Mock implements AppLogger {}

class MockLocalDatabase extends Mock implements LocalDatabase {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

// ---- features/news_feed ----

class MockArticleDetailBloc
    extends MockBloc<ArticleDetailEvent, ArticleDetailState>
    implements ArticleDetailBloc {}

class MockBookmarksBloc extends MockBloc<BookmarksEvent, BookmarksState>
    implements BookmarksBloc {}

class MockNewsApiService extends Mock implements NewsApiService {}

class MockNewsFeedBloc extends MockBloc<NewsFeedEvent, NewsFeedState>
    implements NewsFeedBloc {}

class MockNewsLocalDataSource extends Mock implements NewsLocalDataSource {}

class MockNewsRemoteDataSource extends Mock implements NewsRemoteDataSource {}

class MockNewsRepository extends Mock implements NewsRepository {}

// ---- external packages ----

class MockCacheManager extends Mock implements BaseCacheManager {}

class MockConnectivity extends Mock implements Connectivity {}
