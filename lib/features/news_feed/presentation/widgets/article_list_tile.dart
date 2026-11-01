import 'package:flutter/material.dart';
import 'package:news_hub/core/utils/date_formatter.dart';
import 'package:news_hub/core/widgets/app_network_image.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';

/// One feed row: the title (at most two lines), `source · date` underneath,
/// and a 96×72 thumbnail on the trailing side.
///
/// The whole row is tappable through [onTap]; the widget knows nothing about
/// navigation or blocs.
class ArticleListTile extends StatelessWidget {
  const ArticleListTile({
    required this.article,
    required this.onTap,
    super.key,
  });

  /// The article shown in this row.
  final Article article;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Thumbnail width in logical pixels.
  static const double imageWidth = 96;

  /// Thumbnail height in logical pixels.
  static const double imageHeight = 72;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: <Widget>[
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${article.source.name} · '
                    '${DateFormatter.shortDate(article.publishedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                url: article.imageUrl,
                width: imageWidth,
                height: imageHeight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
