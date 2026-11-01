import 'package:flutter/material.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';

/// A horizontally scrolling row of [ChoiceChip]s, one per [NewsCategory], in
/// enum order.
///
/// The widget is controlled: it shows [selected] and reports taps through
/// [onSelected], which is called only for a chip that is not already
/// selected. It knows nothing about blocs; the feed view wires it up.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The category whose chip is shown as selected.
  final NewsCategory selected;

  /// Called with the tapped chip's category when it was not selected.
  final ValueChanged<NewsCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        spacing: 8,
        children: <Widget>[
          for (final NewsCategory category in NewsCategory.values)
            ChoiceChip(
              label: Text(_label(category)),
              selected: category == selected,
              onSelected: (bool isSelected) {
                // ChoiceChip reports `false` when its selected chip is
                // tapped again; that is not a new selection.
                if (isSelected) {
                  onSelected(category);
                }
              },
            ),
        ],
      ),
    );
  }
}

String _label(NewsCategory category) {
  return switch (category) {
    NewsCategory.general => 'General',
    NewsCategory.business => 'Business',
    NewsCategory.entertainment => 'Entertainment',
    NewsCategory.health => 'Health',
    NewsCategory.science => 'Science',
    NewsCategory.sports => 'Sports',
    NewsCategory.technology => 'Technology',
  };
}
