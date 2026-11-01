import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:news_hub/core/network/interceptors/error_interceptor.dart';
import 'package:news_hub/features/news_feed/data/api/news_api_service.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/data/mappers/article_mapper.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

/// [NewsRemoteDataSource] over the generated [NewsApiService] (Step 19).
///
/// - Every API call runs inside [guardApiCall], so only `AppException`s
///   escape (D10). Mapping to entities happens after the guard, so a bug in
///   our own mapper is never disguised as a `ParsingException`.
/// - [NewsCategory] is mapped to NewsAPI's category string with an
///   exhaustive `switch` (D12), never `.name`: renaming an enum value must
///   not change the request.
/// - `forceRefresh` passes the injected HTTP cache options with
///   [CachePolicy.refreshForceCache] as Retrofit extras; otherwise no extras
///   are sent and the cache interceptor uses its default `forceCache`
///   policy (D16).
final class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  /// Creates the data source. [cacheOptions] is the app's HTTP cache
  /// configuration (the core `CacheOptions` singleton).
  const NewsRemoteDataSourceImpl({
    required this._apiService,
    required this._cacheOptions,
  });

  final NewsApiService _apiService;
  final CacheOptions _cacheOptions;

  @override
  Future<RemoteArticlesPage> getTopHeadlines({
    required NewsCategory category,
    required int page,
    required int pageSize,
    required bool forceRefresh,
  }) async {
    final Map<String, Object?> extras = forceRefresh
        ? _cacheOptions
              .copyWith(policy: CachePolicy.refreshForceCache)
              .toExtra()
        : const <String, Object?>{};
    final NewsResponseModel response = await guardApiCall<NewsResponseModel>(
      () => _apiService.getTopHeadlines(
        category: _apiCategory(category),
        page: page,
        pageSize: pageSize,
        extras: extras,
      ),
    );
    return response.toRemoteArticlesPage();
  }

  @override
  Future<RemoteArticlesPage> searchArticles({
    required String query,
    required int page,
    required int pageSize,
  }) async {
    final NewsResponseModel response = await guardApiCall<NewsResponseModel>(
      () => _apiService.searchArticles(
        query: query,
        page: page,
        pageSize: pageSize,
      ),
    );
    return response.toRemoteArticlesPage();
  }
}

/// NewsAPI's `category` value for [category]. Exhaustive, no default: a new
/// [NewsCategory] does not compile until its API string is chosen here.
String _apiCategory(NewsCategory category) => switch (category) {
  NewsCategory.general => 'general',
  NewsCategory.business => 'business',
  NewsCategory.entertainment => 'entertainment',
  NewsCategory.health => 'health',
  NewsCategory.science => 'science',
  NewsCategory.sports => 'sports',
  NewsCategory.technology => 'technology',
};
