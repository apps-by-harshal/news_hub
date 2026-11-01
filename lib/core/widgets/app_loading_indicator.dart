import 'package:flutter/material.dart';

/// The app's standard "loading" view: a centred spinner that screen readers
/// announce as "Loading".
///
/// Used wherever a whole area waits for data (for example the feed's first
/// load). It animates forever, so widget tests never `pumpAndSettle` while
/// it is on screen.
class AppLoadingIndicator extends StatelessWidget {
  /// Creates the loading view.
  const AppLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(semanticsLabel: 'Loading'),
    );
  }
}
