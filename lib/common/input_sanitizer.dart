import 'package:flutter/foundation.dart';

final RegExp _integerLikeWithZeroFraction = RegExp(r'^[-+]?\d+(\.0+)?$');

/// Returns true for keys that usually map to integer date components.
bool isDateComponentFieldName(String key) {
  final normalized = key.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized == 'year' || normalized == 'month' || normalized == 'day') {
    return true;
  }
  return normalized.endsWith('_year') ||
      normalized.endsWith('_month') ||
      normalized.endsWith('_day') ||
      normalized == 'cycle_day' ||
      normalized == 'period_day' ||
      normalized == 'ovulation_day' ||
      normalized == 'day_of_cycle';
}

/// Parses integer-like input safely.
/// - Accepts int, num values that are whole numbers, and strings like "2" or "2.0".
/// - Returns null for empty/null input.
/// - Throws [FormatException] for non-integer values like "2.5" or "abc".
int? parseNullableIntLike(dynamic raw, {required String fieldName}) {
  if (raw == null) return null;

  if (raw is int) return raw;

  if (raw is num) {
    final isWhole = raw.isFinite && raw == raw.truncateToDouble();
    if (!isWhole) {
      throw FormatException('$fieldName must be a whole number, got "$raw".');
    }
    return raw.toInt();
  }

  final text = raw.toString().trim();
  if (text.isEmpty) return null;

  if (_integerLikeWithZeroFraction.hasMatch(text)) {
    return num.parse(text).toInt();
  }

  throw FormatException(
    '$fieldName must be a whole number (e.g. 2), got "$text".',
  );
}

String toYyyyMmDd(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String parseDateOrToday(dynamic rawDate) {
  final text = rawDate?.toString().trim() ?? '';
  if (text.isEmpty) {
    return toYyyyMmDd(DateTime.now());
  }
  final startsWithIsoDate = RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(text);
  final sourceDay = startsWithIsoDate ? text.substring(0, 10) : null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    throw FormatException('Invalid date "$text". Please use YYYY-MM-DD.');
  }
  final normalized = toYyyyMmDd(parsed.toLocal());
  if (sourceDay != null && sourceDay != normalized) {
    throw FormatException(
      'Invalid date "$text". Please use a real calendar date in YYYY-MM-DD.',
    );
  }
  return normalized;
}

void debugSanitizedField(String key, dynamic value) {
  if (!kDebugMode) return;
  debugPrint('🧼 Sanitized $key -> $value (${value.runtimeType})');
}
