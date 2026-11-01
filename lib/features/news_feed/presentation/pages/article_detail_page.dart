import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/platform/url_opener.dart';
import '../../domain/entities/article.dart';
import '../../domain/usecases/get_bookmark_status.dart';
import '../../domain/usecases/toggle_bookmark.dart';
import '../bloc/article_detail/article_detail_bloc.dart';
import '../bloc/article_detail/article_detail_event.dart';
import '../widgets/article_detail_view.dart';

/// The article detail route's page.
///
/// Creates an [ArticleDetailBloc] for [article] from the get_it use cases,
/// starts it (reads the bookmark status), and lets [BlocProvider] close it
/// when the page is popped. The router passes the article in; this page never
/// imports go_router.
///
/// "Open full article" goes to the app's [UrlOpener], looked
/// up in get_it when the button is tapped, so building the page needs no
/// opener (the router and bootstrap tests register none).
class ArticleDetailPage extends StatelessWidget {
  /// Creates the detail page for [article].
  const ArticleDetailPage({required this.article, super.key});

  /// The article to show.
  final Article article;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ArticleDetailBloc>(
      create: (BuildContext context) => ArticleDetailBloc(
        getBookmarkStatus: getIt<GetBookmarkStatus>(),
        toggleBookmark: getIt<ToggleBookmark>(),
        article: article,
      )..add(const ArticleDetailStarted()),
      child: ArticleDetailView(
        onOpenArticle: (Uri url) => getIt<UrlOpener>().open(url),
      ),
    );
  }
}
