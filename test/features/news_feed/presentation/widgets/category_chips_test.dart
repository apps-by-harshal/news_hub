import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/features/news_feed/domain/entities/news_category.dart';
import 'package:news_hub/features/news_feed/presentation/widgets/category_chips.dart';

import '../../../../helpers/pump_app.dart';

/// Chip labels in [NewsCategory] order, spelled out so a renamed label or a
/// reordered enum fails here.
const List<String> _expectedLabels = <String>[
  'General',
  'Business',
  'Entertainment',
  'Health',
  'Science',
  'Sports',
  'Technology',
];

Future<void> _pumpChips(
  WidgetTester tester, {
  required NewsCategory selected,
  ValueChanged<NewsCategory>? onSelected,
}) {
  return tester.pumpApp(
    CategoryChips(selected: selected, onSelected: onSelected ?? (_) {}),
  );
}

Iterable<ChoiceChip> _chips(WidgetTester tester) {
  return tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
}

void main() {
  group('CategoryChips', () {
    testWidgets('shows one ChoiceChip per category, in enum order', (
      WidgetTester tester,
    ) async {
      await _pumpChips(tester, selected: NewsCategory.general);

      final List<String?> labels = _chips(tester)
          .map((ChoiceChip chip) => (chip.label as Text).data)
          .toList();

      expect(NewsCategory.values, hasLength(_expectedLabels.length));
      expect(labels, _expectedLabels);
    });

    testWidgets('marks only the selected category as selected', (
      WidgetTester tester,
    ) async {
      for (final NewsCategory category in NewsCategory.values) {
        await _pumpChips(tester, selected: category);

        final List<bool> selectedFlags = _chips(tester)
            .map((ChoiceChip chip) => chip.selected)
            .toList();

        expect(selectedFlags, <bool>[
          for (final NewsCategory value in NewsCategory.values)
            value == category,
        ], reason: 'selected: $category');
      }
    });

    testWidgets(
      'tapping an unselected chip reports its category once and does not '
      'change the selection itself',
      (WidgetTester tester) async {
        final List<NewsCategory> selections = <NewsCategory>[];
        await _pumpChips(
          tester,
          selected: NewsCategory.general,
          onSelected: selections.add,
        );

        await tester.tap(find.text('Business'));
        await tester.pump();

        expect(selections, <NewsCategory>[NewsCategory.business]);
        final List<bool> selectedFlags = _chips(tester)
            .map((ChoiceChip chip) => chip.selected)
            .toList();
        expect(selectedFlags.first, isTrue, reason: 'General stays selected');
        expect(selectedFlags.where((bool flag) => flag), hasLength(1));
      },
    );

    testWidgets('tapping the selected chip reports nothing', (
      WidgetTester tester,
    ) async {
      final List<NewsCategory> selections = <NewsCategory>[];
      await _pumpChips(
        tester,
        selected: NewsCategory.science,
        onSelected: selections.add,
      );

      await tester.tap(find.text('Science'));
      await tester.pump();

      expect(selections, isEmpty);
    });

    testWidgets('every chip is reachable on a narrow screen without overflow', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final List<NewsCategory> selections = <NewsCategory>[];
      await _pumpChips(
        tester,
        selected: NewsCategory.general,
        onSelected: selections.add,
      );

      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Technology'));
      await tester.pump();
      await tester.tap(find.text('Technology'));
      await tester.pump();

      expect(selections, <NewsCategory>[NewsCategory.technology]);
    });

    testWidgets('exposes each chip as an enabled, selectable button', (
      WidgetTester tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpChips(tester, selected: NewsCategory.health);

      expect(
        tester.getSemantics(find.text('Health')),
        isSemantics(
          label: 'Health',
          isButton: true,
          isEnabled: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Business')),
        isSemantics(
          label: 'Business',
          isButton: true,
          isEnabled: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });
}
