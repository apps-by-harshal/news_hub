import 'package:flutter/material.dart';

/// A full-width strip telling the user the feed is the saved copy.
///
/// It is a live region, so screen readers announce it when it appears; its
/// label is the message alone (the icon is decorative). Colours come from the
/// theme's `secondaryContainer` pair.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            spacing: 12,
            children: <Widget>[
              Icon(Icons.cloud_off, color: colors.onSecondaryContainer),
              Expanded(
                child: Text(
                  "You're offline. Showing saved headlines.",
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
