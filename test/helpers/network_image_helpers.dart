import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mocktail/mocktail.dart';

import 'mocks.dart';

// Network images in widget tests.
//
// `CachedNetworkImage` loads through a `BaseCacheManager`. The default one
// (`DefaultCacheManager`) needs platform plugins that widget tests don't
// have, so tests put a `MockCacheManager` in the package's static
// `CachedNetworkImageProvider.defaultCacheManager` (`AppNetworkImage` takes
// no cache manager, so `lib/` never imports flutter_cache_manager):
// - `AppNetworkImage`'s own tests assign a fresh mock in `setUp` and stub
//   it per test with `stubImageNeverLoads` / `stubImageFailsToLoad`;
// - tests of widgets that merely *contain* images call
//   `useNeverLoadingImages()` once in `setUpAll`.
// A static field is initialised on first read, so assigning it first means
// `DefaultCacheManager` is never built. Each test file runs in its own
// isolate, so no reset is needed.
//
// Flutter's `imageCache` keeps images (even pending ones) by provider, so a
// file that loads the same URL in several tests calls `clearImageCache()`
// in `tearDown`.

/// The loader's only call for a plain (non-`ImageCacheManager`) cache
/// manager: `getFileStream(url, withProgress: true, headers: null,
/// key: null)` (verified in cached_network_image 4.0.5).
void _whenGetFileStream(
  MockCacheManager cacheManager,
  Stream<FileResponse> Function() stream,
) {
  when(
    () => cacheManager.getFileStream(
      any(),
      key: null,
      headers: null,
      withProgress: true,
    ),
  ).thenAnswer((_) => stream());
}

/// Every image request stays pending forever, so the placeholder shows.
void stubImageNeverLoads(MockCacheManager cacheManager) {
  _whenGetFileStream(cacheManager, () => Stream<FileResponse>.multi((_) {}));
}

/// Every image request fails, so the error widget shows.
void stubImageFailsToLoad(MockCacheManager cacheManager) {
  _whenGetFileStream(
    cacheManager,
    () => Stream<FileResponse>.error(Exception('image unavailable in tests')),
  );
}

/// Makes every `CachedNetworkImage` in this test file show its placeholder
/// without touching the network or any plugin. Call once in `setUpAll`.
MockCacheManager useNeverLoadingImages() {
  final MockCacheManager cacheManager = MockCacheManager();
  stubImageNeverLoads(cacheManager);
  CachedNetworkImageProvider.defaultCacheManager = cacheManager;
  return cacheManager;
}

/// Empties Flutter's image cache, including images still on screen, so the
/// next test loads every URL again.
void clearImageCache() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
}
