import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:news_hub/core/di/injection_container.dart';
import 'package:news_hub/features/news_feed/domain/entities/article.dart';
import 'package:news_hub/features/news_feed/domain/usecases/get_bookmark_status.dart';
import 'package:news_hub/features/news_feed/domain/usecases/toggle_bookmark.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_bloc.dart';
import 'package:news_hub/features/news_feed/presentation/bloc/article_detail/article_detail_event.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/article_detail_view.dart';

/// The article detail route's page (Step 22-3, D19, D20).
///
/// Creates an [ArticleDetailBloc] for [article] from the get_it use cases,
/// starts it (reads the bookmark status), and lets [BlocProvider] close it
/// when the page is popped. The router passes the article in; this page never
/// imports go_router.
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
      child: const ArticleDetailView(),
    );
  }
}
