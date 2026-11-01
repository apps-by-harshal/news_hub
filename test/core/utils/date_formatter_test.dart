import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/utils/date_formatter.dart';

// Every input is built from a *local* wall-clock time, so the expected text
// is the same in any time zone the tests run in (Step 22, Q6). Articles
// arrive in UTC (D11), so most inputs are converted with `toUtc()` first.

void main() {
  group('DateFormatter.shortDate', () {
    test('formats a UTC instant as an en_US short date', () {
      final DateTime publishedAt = DateTime(2026, 10, 30, 12).toUtc();

      expect(DateFormatter.shortDate(publishedAt), 'Oct 30, 2026');
    });

    test('shows the local calendar day just after local midnight', () {
      final DateTime publishedAt = DateTime(2026, 10, 30, 0, 30).toUtc();

      expect(DateFormatter.shortDate(publishedAt), 'Oct 30, 2026');
    });

    test('shows the local calendar day just before local midnight', () {
      final DateTime publishedAt = DateTime(2026, 10, 30, 23, 30).toUtc();

      expect(DateFormatter.shortDate(publishedAt), 'Oct 30, 2026');
    });

    test('formats a local time as is, without padding the day', () {
      final DateTime publishedAt = DateTime(2026, 1, 5, 9);

      expect(DateFormatter.shortDate(publishedAt), 'Jan 5, 2026');
    });

    test('formats the last day of a year', () {
      final DateTime publishedAt = DateTime(2025, 12, 31, 18).toUtc();

      expect(DateFormatter.shortDate(publishedAt), 'Dec 31, 2025');
    });
  });
}
