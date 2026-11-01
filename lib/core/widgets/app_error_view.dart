import 'package:flutter/material.dart';

/// The app's standard error view: an icon, a message and an optional Retry
/// button, centred in the available space.
///
/// It takes ready-made text, so it knows nothing about failure types:
/// callers pass `failure.userMessage`. The content scrolls when it does
/// not fit, so a long message never overflows a small screen.
class AppErrorView extends StatelessWidget {
  /// Creates an error view. Without [onRetry] no button is shown.
  const AppErrorView({required this.message, this.onRetry, super.key});

  /// The text to show, already chosen for the user.
  final String message;

  /// Called when the user taps Retry.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
