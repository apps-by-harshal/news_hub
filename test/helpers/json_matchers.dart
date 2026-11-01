import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart'
    show CheckedFromJsonException;

/// Matches a call (or future) that throws a [CheckedFromJsonException] for
/// [key] in [className], as the `checked: true` DTOs do on a wrong JSON type
/// (D14). A nested failure names the inner class and key, e.g.
/// `ArticleSourceModel.name`.
///
/// Shared by the model and Retrofit service tests (Step 19c).
Matcher throwsCheckedFor({required String className, required String key}) =>
    throwsA(
      isA<CheckedFromJsonException>()
          .having(
            (CheckedFromJsonException e) => e.className,
            'className',
            className,
          )
          .having((CheckedFromJsonException e) => e.key, 'key', key),
    );
