import 'package:flutter/widgets.dart';
import 'package:news_hub/bootstrap.dart';
import 'package:news_hub/core/config/app_config.dart';

/// Entry point. Run with `flutter run --dart-define-from-file=env/dev.json`.
///
/// [AppConfig.fromEnvironment] is the only reader of the compile-time values
/// (CLAUDE.md §7); a missing or invalid `--dart-define` fails fast with its
/// `FormatException` before anything starts. Everything else happens in
/// `bootstrap`, which is tested; this file stays untested (Step 23, Q5).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await bootstrap(config: AppConfig.fromEnvironment()));
}
