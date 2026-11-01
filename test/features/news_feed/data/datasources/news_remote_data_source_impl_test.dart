import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/network/cache/http_cache_config.dart';
import 'package:news_hub/features/news_feed/data/api/news_api_service.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source.dart';
import 'package:news_hub/features/news_feed/data/datasources/news_remote_data_source_impl.dart';
import 'package:news_hub/features/news_feed/data/datasources/remote_articles_page.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

import '../../../../fixtures/article_builders.dart';
import '../../../../helpers/fake_http_client_adapter.dart';
import '../../../../helpers/mocks.dart';

const String _urlA = 'https://example.com/news/a';
const String _urlB = 'https://example.com/news/b';
const String _urlRemoved = 'https://example.com/news/removed';

/// The API category string for every [NewsCategory], written out on purpose
/// (never derived from `.name`), so a change to the mapping breaks a test.
const Map<NewsCategory, String> _apiCategories = <NewsCategory, String>{
  NewsCategory.general: 'general',
  NewsCategory.business: 'business',
  NewsCategory.entertainment: 'entertainment',
  NewsCategory.health: 'health',
  NewsCategory.science: 'science',
  NewsCategory.sports: 'sports',
  NewsCategory.technology: 'technology',
};

/// A raw response with two valid articles and one moderated placeholder,
/// which the mapper must drop.
Map<String, Object?> _responseJson() => <String, Object?>{
  'status': 'ok',
  'totalResults': 38,
  'articles': <Object?>[
    buildArticleJson(_urlA),
    buildArticleJson(_urlB),
    buildArticleJson(_urlRemoved)..['title'] = '[Removed]',
  ],
};

NewsResponseModel _response() => NewsResponseModel.fromJson(_responseJson());

/// What [_responseJson] maps to: the placeholder is dropped,
/// `totalResults` is kept as reported.
RemoteArticlesPage _expectedPage() => RemoteArticlesPage(
  articles: <Article>[buildArticle(_urlA), buildArticle(_urlB)],
  totalResults: 38,
);

/// A real [CheckedFromJsonException], as thrown by the generated `fromJson`.
CheckedFromJsonException _realCheckedFromJsonException() {
  try {
    final NewsResponseModel model = NewsResponseModel.fromJson(
      <String, Object?>{'totalResults': 'not a number'},
    );
    fail('Expected a CheckedFromJsonException, got $model');
  } on CheckedFromJsonException catch (e) {
    return e;
  }
}

/// A real [TypeError] from a failed cast.
TypeError _realTypeError() {
  try {
    const Object notAnInt = 'not a number';
    final int value = notAnInt as int;
    fail('Expected a TypeError, got $value');
  } on TypeError catch (e) {
    return e;
  }
}

void main() {
  late MockNewsApiService apiService;
  late CacheOptions cacheOptions;
  late NewsRemoteDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(const <String, Object?>{});
  });

  setUp(() {
    apiService = MockNewsApiService();
    cacheOptions = createHttpCacheOptions();
    dataSource = NewsRemoteDataSourceImpl(
      apiService: apiService,
      cacheOptions: cacheOptions,
    );
  });

  void stubTopHeadlines(Future<NewsResponseModel> Function() answer) {
    when(
      () => apiService.getTopHeadlines(
        category: any(named: 'category'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        extras: any(named: 'extras'),
      ),
    ).thenAnswer((_) => answer());
  }

  void stubSearch(Future<NewsResponseModel> Function() answer) {
    when(
      () => apiService.searchArticles(
        query: any(named: 'query'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<RemoteArticlesPage> getTopHeadlines({
    NewsCategory category = NewsCategory.general,
    bool forceRefresh = false,
  }) => dataSource.getTopHeadlines(
    category: category,
    page: 1,
    pageSize: 20,
    forceRefresh: forceRefresh,
  );

  /// The `extras` map passed to the single `getTopHeadlines` call.
  Map<String, Object?> capturedExtras() {
    final List<Object?> captured = verify(
      () => apiService.getTopHeadlines(
        category: any(named: 'category'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        extras: captureAny(named: 'extras'),
      ),
    ).captured;
    return captured.single as Map<String, Object?>;
  }

  group('getTopHeadlines', () {
    group('category → API string', () {
      test('covers every NewsCategory', () {
        expect(_apiCategories.keys, unorderedEquals(NewsCategory.values));
      });

      for (final MapEntry<NewsCategory, String> entry
          in _apiCategories.entries) {
        test('${entry.key.name} → "${entry.value}"', () async {
          stubTopHeadlines(() async => _response());

          await getTopHeadlines(category: entry.key);

          verify(
            () => apiService.getTopHeadlines(
              category: entry.value,
              page: 1,
              pageSize: 20,
              extras: any(named: 'extras'),
            ),
          ).called(1);
          verifyNoMoreInteractions(apiService);
        });
      }
    });

    test('forwards page and pageSize unchanged', () async {
      stubTopHeadlines(() async => _response());

      await dataSource.getTopHeadlines(
        category: NewsCategory.science,
        page: 3,
        pageSize: 7,
        forceRefresh: false,
      );

      verify(
        () => apiService.getTopHeadlines(
          category: 'science',
          page: 3,
          pageSize: 7,
          extras: any(named: 'extras'),
        ),
      ).called(1);
      verifyNoMoreInteractions(apiService);
    });

    test('forceRefresh false → no extras (forceCache policy)', () async {
      stubTopHeadlines(() async => _response());

      await getTopHeadlines();

      expect(capturedExtras(), isEmpty);
    });

    test('forceRefresh true → the injected cache options with '
        'refreshForceCache', () async {
      stubTopHeadlines(() async => _response());

      await getTopHeadlines(forceRefresh: true);

      final Map<String, Object?> extras = capturedExtras();
      expect(extras, hasLength(1));
      expect(
        extras.values.single,
        isA<CacheOptions>()
            .having(
              (CacheOptions o) => o.policy,
              'policy',
              CachePolicy.refreshForceCache,
            )
            .having(
              (CacheOptions o) => o.store,
              'store',
              same(cacheOptions.store),
            )
            .having(
              (CacheOptions o) => o.maxStale,
              'maxStale',
              cacheOptions.maxStale,
            ),
      );
      expect(cacheOptions.policy, CachePolicy.forceCache);
    });

    test('maps the response to a RemoteArticlesPage', () async {
      stubTopHeadlines(() async => _response());

      expect(await getTopHeadlines(), _expectedPage());
    });

    group('errors', () {
      test('a DioException holding an AppException → rethrows it', () async {
        const UnauthorizedException attached = UnauthorizedException(
          message: 'Your API key is invalid.',
          code: 'apiKeyInvalid',
        );
        stubTopHeadlines(
          () async => throw DioException(
            requestOptions: RequestOptions(path: '/top-headlines'),
            error: attached,
          ),
        );

        await expectLater(getTopHeadlines(), throwsA(same(attached)));
      });

      test('a bare DioException → mapped (connectionTimeout → '
          'NetworkException)', () async {
        stubTopHeadlines(
          () async => throw DioException.connectionTimeout(
            timeout: const Duration(seconds: 10),
            requestOptions: RequestOptions(path: '/top-headlines'),
          ),
        );

        await expectLater(getTopHeadlines(), throwsA(isA<NetworkException>()));
      });

      test('CheckedFromJsonException → ParsingException naming the '
          'class and key', () async {
        final CheckedFromJsonException error = _realCheckedFromJsonException();
        stubTopHeadlines(() async => throw error);

        await expectLater(
          getTopHeadlines(),
          throwsA(
            isA<ParsingException>().having(
              (ParsingException e) => e.message,
              'message',
              contains('NewsResponseModel.totalResults'),
            ),
          ),
        );
      });

      test('TypeError → ParsingException', () async {
        final TypeError error = _realTypeError();
        stubTopHeadlines(() async => throw error);

        await expectLater(getTopHeadlines(), throwsA(isA<ParsingException>()));
      });

      test('any other error propagates unchanged', () async {
        final StateError error = StateError('bug');
        stubTopHeadlines(() async => throw error);

        await expectLater(getTopHeadlines(), throwsA(same(error)));
      });
    });
  });

  group('searchArticles', () {
    test('forwards query, page and pageSize, and maps the response', () async {
      stubSearch(() async => _response());

      final RemoteArticlesPage page = await dataSource.searchArticles(
        query: 'flutter',
        page: 2,
        pageSize: 10,
      );

      expect(page, _expectedPage());
      verify(
        () =>
            apiService.searchArticles(query: 'flutter', page: 2, pageSize: 10),
      ).called(1);
      verifyNoMoreInteractions(apiService);
    });

    test('a DioException holding an AppException → rethrows it', () async {
      const NetworkException attached = NetworkException('offline');
      stubSearch(
        () async => throw DioException(
          requestOptions: RequestOptions(path: '/everything'),
          error: attached,
        ),
      );

      await expectLater(
        dataSource.searchArticles(query: 'flutter', page: 1, pageSize: 20),
        throwsA(same(attached)),
      );
    });
  });

  group('through a real Dio and the generated NewsApiService', () {
    late FakeHttpClientAdapter adapter;

    NewsRemoteDataSource buildWithDio(FakeResponder responder) {
      adapter = FakeHttpClientAdapter(<FakeResponder>[responder]);
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://newsapi.test/v2'))
        ..httpClientAdapter = adapter;
      return NewsRemoteDataSourceImpl(
        apiService: NewsApiService(dio),
        cacheOptions: createHttpCacheOptions(),
      );
    }

    test('sends the API query and maps the parsed body', () async {
      final NewsRemoteDataSource remote = buildWithDio(
        jsonResponse(200, _responseJson()),
      );

      final RemoteArticlesPage page = await remote.getTopHeadlines(
        category: NewsCategory.business,
        page: 2,
        pageSize: 5,
        forceRefresh: false,
      );

      expect(page, _expectedPage());
      final Uri uri = adapter.requests.single.uri;
      expect(uri.path, '/v2/top-headlines');
      expect(uri.queryParameters, <String, String>{
        'category': 'business',
        'page': '2',
        'pageSize': '5',
      });
    });

    test('a JSON list body → ParsingException', () async {
      final NewsRemoteDataSource remote = buildWithDio(
        jsonResponse(200, <Object?>[]),
      );

      await expectLater(
        remote.searchArticles(query: 'flutter', page: 1, pageSize: 20),
        throwsA(isA<ParsingException>()),
      );
    });

    test('a plain-text body → ParsingException', () async {
      final NewsRemoteDataSource remote = buildWithDio(
        rawResponse(200, 'not json'),
      );

      await expectLater(
        remote.searchArticles(query: 'flutter', page: 1, pageSize: 20),
        throwsA(isA<ParsingException>()),
      );
    });

    test('a field of the wrong type → ParsingException', () async {
      final NewsRemoteDataSource remote = buildWithDio(
        jsonResponse(200, <String, Object?>{'totalResults': 'x'}),
      );

      await expectLater(
        remote.getTopHeadlines(
          category: NewsCategory.general,
          page: 1,
          pageSize: 20,
          forceRefresh: false,
        ),
        throwsA(
          isA<ParsingException>().having(
            (ParsingException e) => e.message,
            'message',
            contains('NewsResponseModel.totalResults'),
          ),
        ),
      );
    });
  });
}
