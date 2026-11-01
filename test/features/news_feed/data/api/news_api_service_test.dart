import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/config/flavor.dart';
import 'package:news_hub/core/logging/log_level.dart';
import 'package:news_hub/core/network/cache/http_cache_config.dart';
import 'package:news_hub/core/network/dio_client.dart';
import 'package:news_hub/core/network/interceptors/api_key_interceptor.dart';
import 'package:news_hub/features/news_feed/data/api/news_api_service.dart';
import 'package:news_hub/features/news_feed/data/models/news_response_model.dart';
import 'package:retrofit/retrofit.dart' show ParseErrorLogger;

import '../../../../fixtures/fixture_reader.dart';
import '../../../../helpers/fake_http_client_adapter.dart';
import '../../../../helpers/json_matchers.dart';
import '../../../../helpers/mocks.dart';

const String _baseUrl = 'https://newsapi.test/v2';
const String _apiKey = 'test-api-key';
const String _topHeadlinesFixture = 'top_headlines_response.json';
const String _emptyFixture = 'empty_response.json';

/// A service over a bare `Dio` (no interceptors) whose transport is [adapter].
NewsApiService _service(
  FakeHttpClientAdapter adapter, {
  String dioBaseUrl = _baseUrl,
  String? serviceBaseUrl,
  ParseErrorLogger? errorLogger,
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: dioBaseUrl))
    ..httpClientAdapter = adapter;
  return NewsApiService(dio, baseUrl: serviceBaseUrl, errorLogger: errorLogger);
}

Future<NewsResponseModel> _topHeadlines(
  NewsApiService service, {
  Map<String, Object?> extras = const <String, Object?>{},
}) {
  return service.getTopHeadlines(
    category: 'technology',
    page: 2,
    pageSize: 20,
    extras: extras,
  );
}

Future<NewsResponseModel> _search(
  NewsApiService service, {
  String query = 'flutter',
}) {
  return service.searchArticles(query: query, page: 3, pageSize: 20);
}

NewsResponseModel _expectedFrom(String fixtureName) =>
    NewsResponseModel.fromJson(fixtureJson(fixtureName));

/// `totalResults` as a String: a wrong type in the envelope itself.
Map<String, Object?> _wrongEnvelopeTypeBody() => <String, Object?>{
  'status': 'ok',
  'totalResults': '38',
  'articles': <Object?>[],
};

/// `title` as an int: a wrong type inside a nested article.
Map<String, Object?> _wrongNestedTypeBody() => <String, Object?>{
  'status': 'ok',
  'totalResults': 1,
  'articles': <Object?>[
    <String, Object?>{'title': 1},
  ],
};

AppConfig _config() => AppConfig(
  flavor: Flavor.dev,
  apiBaseUrl: Uri.parse(_baseUrl),
  apiKey: _apiKey,
  enableHttpLogging: false,
  logLevel: LogLevel.info,
);

/// Records what the generated client hands to its [ParseErrorLogger].
final class _RecordingParseErrorLogger implements ParseErrorLogger {
  final List<Object> loggedErrors = <Object>[];
  final List<RequestOptions> loggedOptions = <RequestOptions>[];

  @override
  void logError(
    Object error,
    StackTrace stackTrace,
    RequestOptions options, {
    Response<Object?>? response,
  }) {
    loggedErrors.add(error);
    loggedOptions.add(options);
  }
}

void main() {
  group('getTopHeadlines', () {
    test('sends a GET to /v2/top-headlines (base URL without "/")', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(_service(adapter));

      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.host, 'newsapi.test');
      expect(request.uri.path, '/v2/top-headlines');
    });

    test('keeps the same path when the base URL ends with "/"', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(_service(adapter, dioBaseUrl: '$_baseUrl/'));

      expect(adapter.requests.single.uri.path, '/v2/top-headlines');
    });

    test('sends exactly category, page and pageSize as query', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(_service(adapter));

      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'category': 'technology',
        'page': '2',
        'pageSize': '20',
      });
    });

    test('parses the top headlines fixture into NewsResponseModel', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_topHeadlinesFixture))],
      );

      final NewsResponseModel result = await _topHeadlines(_service(adapter));

      expect(result, _expectedFrom(_topHeadlinesFixture));
    });

    test('parses the empty fixture', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      final NewsResponseModel result = await _topHeadlines(_service(adapter));

      expect(result, _expectedFrom(_emptyFixture));
    });

    test('passes extras on to RequestOptions.extra', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(
        _service(adapter),
        extras: <String, Object?>{'news_hub_test': 'marker'},
      );

      expect(
        adapter.requests.single.extra,
        containsPair('news_hub_test', 'marker'),
      );
    });

    test('leaves RequestOptions.extra empty for empty extras', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(_service(adapter));

      expect(adapter.requests.single.extra, isEmpty);
    });

    test('throws CheckedFromJsonException for a wrong envelope type', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, _wrongEnvelopeTypeBody())],
      );

      await expectLater(
        _topHeadlines(_service(adapter)),
        throwsCheckedFor(className: 'NewsResponseModel', key: 'totalResults'),
      );
    });

    test('hands the parse error to errorLogger, then rethrows it', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, _wrongEnvelopeTypeBody())],
      );
      final _RecordingParseErrorLogger logger = _RecordingParseErrorLogger();

      Object? thrown;
      try {
        await _topHeadlines(_service(adapter, errorLogger: logger));
      } on CheckedFromJsonException catch (error) {
        thrown = error;
      }

      expect(thrown, isA<CheckedFromJsonException>());
      expect(logger.loggedErrors, hasLength(1));
      expect(identical(logger.loggedErrors.single, thrown), isTrue);
      expect(logger.loggedOptions.single.path, '/top-headlines');
    });
  });

  group('searchArticles', () {
    test('sends a GET to /v2/everything', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _search(_service(adapter));

      final RequestOptions request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.host, 'newsapi.test');
      expect(request.uri.path, '/v2/everything');
    });

    test('sends exactly q, page and pageSize as query', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _search(_service(adapter));

      expect(adapter.requests.single.uri.queryParameters, <String, String>{
        'q': 'flutter',
        'page': '3',
        'pageSize': '20',
      });
    });

    test(
      'encodes q so spaces, "&" and non-ASCII come back unchanged',
      () async {
        const String query = 'climate change & AI: München?';
        final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
          <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
        );

        await _search(_service(adapter), query: query);

        final Map<String, String> sent =
            adapter.requests.single.uri.queryParameters;
        expect(sent['q'], query);
        expect(sent.keys, unorderedEquals(<String>['q', 'page', 'pageSize']));
      },
    );

    test('parses the fixture into NewsResponseModel', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_topHeadlinesFixture))],
      );

      final NewsResponseModel result = await _search(_service(adapter));

      expect(result, _expectedFrom(_topHeadlinesFixture));
    });

    test('throws CheckedFromJsonException for a wrong nested type', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, _wrongNestedTypeBody())],
      );

      await expectLater(
        _search(_service(adapter)),
        throwsCheckedFor(className: 'ArticleModel', key: 'title'),
      );
    });
  });

  group('constructor', () {
    test('a baseUrl override replaces the Dio base URL', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(
        _service(adapter, serviceBaseUrl: 'https://other.test/v3'),
      );

      final Uri uri = adapter.requests.single.uri;
      expect(uri.host, 'other.test');
      expect(uri.path, '/v3/top-headlines');
    });
  });

  group('through createDioClient', () {
    late CacheOptions cacheOptions;

    NewsApiService productionService(FakeHttpClientAdapter adapter) {
      final Dio dio = createDioClient(
        config: _config(),
        logger: MockAppLogger(),
        cacheOptions: cacheOptions,
      )..httpClientAdapter = adapter;
      return NewsApiService(dio);
    }

    setUp(() {
      cacheOptions = createHttpCacheOptions();
    });

    test('sends the API key as a header and never in the URL', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_emptyFixture))],
      );

      await _topHeadlines(productionService(adapter));

      final RequestOptions request = adapter.requests.single;
      expect(request.headers[ApiKeyInterceptor.headerName], _apiKey);
      expect(request.uri.toString(), isNot(contains(_apiKey)));
      expect(
        request.uri.queryParameters.keys.map((String k) => k.toLowerCase()),
        isNot(contains('apikey')),
      );
    });

    test('answers an identical second call from the HTTP cache', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[jsonResponse(200, fixtureJson(_topHeadlinesFixture))],
      );
      final NewsApiService service = productionService(adapter);

      final NewsResponseModel first = await _topHeadlines(service);
      final NewsResponseModel second = await _topHeadlines(service);

      expect(adapter.requests, hasLength(1));
      expect(second, first);
    });

    test('refreshForceCache extras bypass the cached response', () async {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        <FakeResponder>[
          jsonResponse(200, fixtureJson(_topHeadlinesFixture)),
          jsonResponse(200, fixtureJson(_emptyFixture)),
        ],
      );
      final NewsApiService service = productionService(adapter);

      await _topHeadlines(service);
      final NewsResponseModel refreshed = await _topHeadlines(
        service,
        extras: cacheOptions
            .copyWith(policy: CachePolicy.refreshForceCache)
            .toExtra(),
      );

      expect(adapter.requests, hasLength(2));
      expect(refreshed, _expectedFrom(_emptyFixture));
    });
  });
}
