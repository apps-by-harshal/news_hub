import 'package:dio/dio.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';
import 'package:retrofit/retrofit.dart';

part 'news_api_service.g.dart';

/// Retrofit client for NewsAPI's `/top-headlines` and `/everything`.
///
/// A thin mirror of the raw API (D16): parameters carry the API's own names
/// and string values. `NewsRemoteDataSourceImpl` (Step 19) maps
/// `NewsCategory` to the `category` string with an exhaustive `switch`,
/// chooses the page size, builds the cache extras, and wraps every call in
/// `guardApiCall` (D10).
///
/// **Base URL.** Taken from the injected [Dio]'s `BaseOptions.baseUrl`
/// (`createDioClient` sets it from `AppConfig.apiBaseUrl`); never hard-coded
/// here. Paths start with `/` because Dio joins `baseUrl + path` as plain
/// strings (then collapses `//`), so `https://newsapi.org/v2` works with or
/// without a trailing slash. The `baseUrl` constructor parameter exists for
/// tests.
///
/// **API key.** Never a parameter: `ApiKeyInterceptor` sends it in the
/// `X-Api-Key` header, so it stays out of URLs, logs and cache keys.
///
/// **Errors.** Transport and HTTP failures surface as `DioException`
/// (already holding an `AppException` when the full interceptor chain runs);
/// a body of the wrong shape throws `CheckedFromJsonException` after being
/// passed to `errorLogger`, if one is set. Production leaves `errorLogger`
/// null: `guardApiCall` and the repository do the logging, and the logger
/// would receive the response.
@RestApi()
abstract class NewsApiService {
  factory NewsApiService(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _NewsApiService;

  /// `GET /top-headlines?category=…&page=…&pageSize=…`.
  ///
  /// [extras] are copied into the request's `RequestOptions.extra`.
  /// Pull-to-refresh passes the HTTP cache options with
  /// `CachePolicy.refreshForceCache` (`CacheOptions.toExtra()`); every other
  /// call passes `const <String, Object?>{}` and gets the default
  /// `forceCache` policy.
  @GET('/top-headlines')
  Future<NewsResponseModel> getTopHeadlines({
    @Query('category') required String category,
    @Query('page') required int page,
    @Query('pageSize') required int pageSize,
    @Extras() required Map<String, Object?> extras,
  });

  /// `GET /everything?q=…&page=…&pageSize=…`.
  ///
  /// [query] is sent as `q`, URL-encoded by Dio. The caller passes a
  /// trimmed, non-blank query (D12).
  @GET('/everything')
  Future<NewsResponseModel> searchArticles({
    @Query('q') required String query,
    @Query('page') required int page,
    @Query('pageSize') required int pageSize,
  });
}
