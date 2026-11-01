import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The app's only way to show a network image (Step 22).
///
/// Wraps `CachedNetworkImage` so the rest of the app never depends on it
/// directly. Three looks, all at the given size so layouts never jump:
/// - while loading: a plain surface-coloured box ([placeholderKey]);
/// - no URL, a blank URL, or a failed load: the same box with a newspaper
///   icon ([fallbackKey]).
///
/// There is no cache-manager parameter, so `lib/` never imports
/// `flutter_cache_manager`; widget tests replace the package's default
/// cache manager instead (`test/helpers/network_image_helpers.dart`).
class AppNetworkImage extends StatelessWidget {
  /// Creates a network image. [url] is trimmed; `null` or blank shows the
  /// fallback without touching the network.
  const AppNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  /// Key of the box shown while the image loads.
  static const Key placeholderKey = ValueKey<String>(
    'app_network_image_placeholder',
  );

  /// Key of the box shown when there is no image to load or loading failed.
  static const Key fallbackKey = ValueKey<String>('app_network_image_fallback');

  /// The image address, usually `Article.imageUrl`.
  final String? url;

  /// The width of the image and of its placeholder and fallback.
  final double? width;

  /// The height of the image and of its placeholder and fallback.
  final double? height;

  /// How the loaded image fills its box.
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = url?.trim() ?? '';
    if (imageUrl.isEmpty) {
      return _ImageBox(
        key: fallbackKey,
        width: width,
        height: height,
        showIcon: true,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (BuildContext context, String _) => _ImageBox(
        key: placeholderKey,
        width: width,
        height: height,
        showIcon: false,
      ),
      errorWidget: (BuildContext context, String _, Object _) => _ImageBox(
        key: fallbackKey,
        width: width,
        height: height,
        showIcon: true,
      ),
    );
  }
}

/// A box of the image's size in the theme's surface colour, optionally with
/// a newspaper icon.
class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.width,
    required this.height,
    required this.showIcon,
    super.key,
  });

  final double? width;
  final double? height;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: showIcon
            ? Center(
                child: Icon(Icons.newspaper, color: colors.onSurfaceVariant),
              )
            : null,
      ),
    );
  }
}
