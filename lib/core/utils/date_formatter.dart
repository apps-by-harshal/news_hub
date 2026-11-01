import 'package:intl/intl.dart';

/// Date text shown in the UI.
///
/// Articles carry `publishedAt` in UTC; the UI shows the reader's
/// local calendar day, so every method converts with [DateTime.toLocal]
/// first. Formatting uses intl's default locale (`en_US` until l10n is
/// planned), whose date symbols are built in, so no
/// `initializeDateFormatting` call is needed.
abstract final class DateFormatter {
  /// A short date such as `Oct 30, 2026` (intl's `yMMMd` skeleton), in the
  /// device's local time zone.
  static String shortDate(DateTime dateTime) =>
      DateFormat.yMMMd().format(dateTime.toLocal());
}
