# News Hub

A Flutter news reader built on the [NewsAPI.org](https://newsapi.org/) API.
It shows top headlines by category, keeps working offline with the last
headlines it loaded, lets you bookmark articles for later, and opens the full
article in the browser.

The codebase is a test-driven, feature-first Clean Architecture app:
824 tests, 100% line coverage of hand-written code, and a strict analyzer
configuration with zero issues.

---

## Features

- **Top headlines by category:** General, Business, Entertainment, Health,
  Science, Sports and Technology, switched with chips at the top of the feed.
- **Infinite scroll:** the next page loads as you reach the end of the list,
  up to the 100 results NewsAPI's free plan allows.
- **Pull to refresh:** fetches fresh headlines and bypasses the HTTP cache.
- **Offline reading:** every page 1 that loads is saved on the device. With no
  connection (or when NewsAPI fails), the feed shows the saved headlines with
  an offline banner.
- **Article detail:** image, title, source and date, author, description,
  content preview and the article link.
- **Bookmarks:** save or remove an article from its detail screen; the
  Bookmarks screen (from the feed's app bar) lists them newest first, works
  offline and updates when you come back from an article.
- **Open full article:** opens the article's web page in an in-app browser
  tab (Custom Tabs on Android, Safari View on iOS).
- **Light and dark theme** following the system setting (Material 3).
- **Friendly errors:** every failure is shown with plain-language copy and a
  Retry where it makes sense; technical details go to the logs only.

---

## Tech stack

| Concern | Package |
|---|---|
| State management | `flutter_bloc` (Bloc only, no Cubit), `bloc_concurrency` |
| Routing | `go_router` |
| Networking | `dio`, `retrofit` (generated API client), `dio_cache_interceptor` |
| JSON | `json_annotation` + `json_serializable` |
| Local storage | Hive CE (`hive_ce`, `hive_ce_flutter`, `hive_ce_generator`) |
| Connectivity | `connectivity_plus` |
| Dependency injection | `get_it` (manual registration) |
| Images | `cached_network_image` |
| Links | `url_launcher` |
| Logging | `logger`, behind an `AppLogger` interface |
| Equality | `equatable` |
| Dates | `intl` |
| Testing | `flutter_test`, `bloc_test`, `mocktail` |
| Code generation | `build_runner`, `retrofit_generator`, `json_serializable`, `hive_ce_generator` |

---

## Architecture

The app follows **feature-first Clean Architecture**. Each feature has three
layers, and dependencies point inwards only:

```
presentation ──► domain ◄── data
                   ▲
                 core
```

- **Domain** (pure Dart): entities (`Article`, `PaginatedArticles`,
  `NewsCategory`), the `NewsRepository` contract and one use case per action
  (`GetTopHeadlines`, `GetBookmarks`, `ToggleBookmark`, …). No Flutter, Dio or
  Hive imports.
- **Data**: the Retrofit `NewsApiService`, DTOs and mappers, remote and local
  data sources, and `NewsRepositoryImpl`, which decides where data comes from.
- **Presentation**: one Bloc per screen (sealed events and states), views that
  only render state and send events, and pages that create the bloc.
- **Core** (shared, feature-agnostic): config, networking (Dio client and
  interceptors), storage, error types, `Result<T>`, logging, theme, shared
  widgets, platform services and the DI composition root.

### Key design decisions

- **Errors as values.** The data layer throws typed `AppException`s; the
  repository turns them into a sealed `Result<T>` (`Success` / `Failure`)
  carrying a domain failure. Blocs pattern-match on the result and never use
  `try/catch` for flow control. The UI shows a plain-language message chosen
  by failure type, never the technical message.
- **One mapping point per boundary.** `DioException` becomes `AppException`
  only in `ErrorInterceptor`; Hive errors become `CacheException` only in
  `guardStorageCall`.
- **Network-first with an offline fallback.** Headlines come from the network
  and are saved locally; when the request fails (or the device is offline)
  page 1 is served from the cache and the screen says so. A rejected API key
  is never hidden behind cached data. Bookmarks are local only.
- **HTTP interceptor chain:** API key (sent in the `X-Api-Key` header, never
  in the URL) → HTTP cache → retry with backoff for idempotent requests →
  logging (secrets redacted) → error mapping.
- **Blocs live with their page.** Each page creates its bloc in a
  `BlocProvider`, which closes it; blocs are never registered in get_it.
  Event transformers (`droppable`, `restartable`) and a request id keep
  overlapping requests from showing stale results.
- **Platform plugins behind interfaces.** `url_launcher` is wrapped by a
  `UrlOpener` interface in `core/platform/`, so tests never touch the plugin.
- **Strict typing.** No `dynamic` in hand-written code, explicit types on all
  public APIs, `strict-casts` / `strict-inference` / `strict-raw-types`, and
  async misuse (`unawaited_futures`, `discarded_futures`) as errors.

---

## Project structure

```
lib/
├── main.dart                 # entry point: reads the config, runs bootstrap
├── bootstrap.dart            # DI, local storage, error hooks, bloc observer
├── app.dart                  # MaterialApp.router with the light/dark theme
├── startup_error_app.dart    # shown if local storage can't be opened
├── hive_adapters.dart        # the app's list of Hive types (+ generated files)
├── router/                   # route table and route names
├── core/
│   ├── config/               # AppConfig (from --dart-define), constants
│   ├── di/                   # get_it composition root
│   ├── error/                # AppException and domain failures
│   ├── logging/              # AppLogger interface and implementation
│   ├── network/              # Dio client, interceptors, HTTP cache, connectivity
│   ├── platform/             # UrlOpener (url_launcher wrapper)
│   ├── result/               # sealed Result<T>
│   ├── router/               # navigation logging observer
│   ├── storage/              # Hive database and error guard
│   ├── theme/                # Material 3 theme
│   ├── usecase/              # UseCase<T, P> contract
│   ├── utils/                # failure messages, date format, bloc observer
│   └── widgets/              # loading, error and network image widgets
└── features/
    └── news_feed/
        ├── domain/           # entities, repository contract, use cases
        ├── data/             # API service, models, mappers, data sources, repository
        ├── presentation/     # blocs, pages and widgets (feed, detail, bookmarks)
        └── news_feed_injection.dart

test/                         # mirrors lib/, plus fixtures/ and helpers/
env/dev.example.json          # template for your environment file
```

---

## Getting started

### Prerequisites

- **Flutter 3.47.7** (stable) with **Dart 3.13.5** or newer.
- An Android emulator/device or an iOS simulator/device (Xcode on macOS).
- A free **NewsAPI key** from <https://newsapi.org/register>.

### 1. Get the code and dependencies

```bash
git clone https://github.com/pathak-harshal/news_hub.git
cd news_hub
flutter pub get
```

### 2. Create your environment file

The app reads its settings at compile time from a JSON file passed with
`--dart-define-from-file`. Copy the template and put your key in it:

```bash
cp env/dev.example.json env/dev.json
```

```json
{
  "FLAVOR": "dev",
  "API_BASE_URL": "https://newsapi.org/v2",
  "API_KEY": "your-newsapi-key",
  "ENABLE_HTTP_LOGGING": true,
  "LOG_LEVEL": "debug"
}
```

| Key | Required | Meaning |
|---|---|---|
| `FLAVOR` | yes | Environment name; only `dev` exists for now. |
| `API_BASE_URL` | yes | NewsAPI base URL; must be an absolute `https` URL. |
| `API_KEY` | yes | Your NewsAPI key. Empty or the template placeholder is rejected. |
| `ENABLE_HTTP_LOGGING` | no | `true` logs each request and response line (headers redacted, never bodies). Default `false`. |
| `LOG_LEVEL` | no | `debug`, `info`, `warning` or `error`. Default `info`. |

`env/dev.json` is git-ignored, so your key is never committed. If a value is
missing or invalid, the app stops at launch with a message naming the key.

### 3. Run the app

```bash
flutter run --dart-define-from-file=env/dev.json
```

In VS Code or Android Studio, add `--dart-define-from-file=env/dev.json` to
the run configuration's arguments.

---

## Development

### Code generation

Retrofit clients, JSON models and Hive adapters are generated. The generated
files are committed, so you only need this after changing an annotated class:

```bash
dart run build_runner build
```

Never edit `*.g.dart` files by hand, and never delete
`lib/hive_adapters.g.yaml`: it pins the Hive type ids and field indices.

### Tests and coverage

```bash
flutter test                      # all 824 tests
flutter test --coverage           # writes coverage/lcov.info
```

Tests never touch the network or platform plugins: the API is tested through a
fake HTTP adapter, Hive against a temporary directory, and widgets with mocked
blocs or fake callbacks.

### Static analysis and formatting

```bash
dart format .
flutter analyze                   # must report no issues
```

The rules live in `analysis_options.yaml`. Inside `lib/`, the app's own files
are imported with relative paths (`prefer_relative_imports`); tests import
`lib/` with `package:news_hub/…`.

---

## Notes and limitations

- **NewsAPI's free Developer plan is for development only.** It may not be
  used in a published app; a release would need a paid key or, better, a
  small backend proxy that holds the key. `API_BASE_URL` is configurable for
  exactly that reason. Anything compiled into an app can be extracted, so a
  key shipped in a release build is not secret.
- The free plan returns at most 100 results per query and has a daily request
  limit; the HTTP cache keeps repeated identical requests off that quota.
- Only the `dev` environment exists. Staging and production builds (flavors,
  schemes, separate env files) are not set up yet.
- The app targets Android and iOS.
