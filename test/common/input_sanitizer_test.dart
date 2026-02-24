import 'package:flutter_test/flutter_test.dart';
import 'package:mind_buddy/common/input_sanitizer.dart';

void main() {
  group('parseNullableIntLike', () {
    test('accepts integer-like inputs including 2.0', () {
      expect(parseNullableIntLike(2, fieldName: 'month'), 2);
      expect(parseNullableIntLike(2.0, fieldName: 'month'), 2);
      expect(parseNullableIntLike('2', fieldName: 'month'), 2);
      expect(parseNullableIntLike('2.0', fieldName: 'month'), 2);
      expect(parseNullableIntLike(' 2.000 ', fieldName: 'month'), 2);
    });

    test('returns null for empty/null input', () {
      expect(parseNullableIntLike(null, fieldName: 'month'), isNull);
      expect(parseNullableIntLike('', fieldName: 'month'), isNull);
      expect(parseNullableIntLike('   ', fieldName: 'month'), isNull);
    });

    test('rejects non-integer values with clear error', () {
      expect(
        () => parseNullableIntLike('2.5', fieldName: 'month'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parseNullableIntLike('abc', fieldName: 'month'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('isDateComponentFieldName', () {
    test('detects common date component keys', () {
      expect(isDateComponentFieldName('month'), isTrue);
      expect(isDateComponentFieldName('year'), isTrue);
      expect(isDateComponentFieldName('cycle_day'), isTrue);
      expect(isDateComponentFieldName('period_day'), isTrue);
      expect(isDateComponentFieldName('created_at'), isFalse);
    });
  });

  group('parseDateOrToday', () {
    test('normalizes valid dates to yyyy-mm-dd', () {
      expect(parseDateOrToday('2026-02-03'), '2026-02-03');
      expect(parseDateOrToday('2026-02-03T10:20:30Z'), '2026-02-03');
    });

    test('throws for invalid date strings', () {
      expect(
        () => parseDateOrToday('2026-13-99'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
