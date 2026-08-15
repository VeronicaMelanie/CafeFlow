import 'package:fivetogo_scheduler/core/api/api_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseDateOnly keeps a local calendar date, not UTC midnight', () {
    final date = ApiDateTime.parseDateOnly('2026-09-10');
    expect(date, DateTime(2026, 9, 10));
    expect(date.isUtc, isFalse);
    expect(date.hour, 0);
  });

  test('combineDateAndTime places TIME on the DATE as local wall clock', () {
    final date = DateTime(2026, 9, 23);
    expect(
      ApiDateTime.combineDateAndTime(date, '04:00:00.000'),
      DateTime(2026, 9, 23, 4, 0, 0),
    );
    expect(
      ApiDateTime.combineDateAndTime(date, '10:00:00'),
      DateTime(2026, 9, 23, 10, 0, 0),
    );
    expect(ApiDateTime.combineDateAndTime(date, null), isNull);
  });

  test('parseTimestamptz converts ISO UTC to local DateTime', () {
    final local = ApiDateTime.parseTimestamptz('2026-09-10T04:00:00.000Z');
    expect(local.isUtc, isFalse);
    expect(local.toUtc(), DateTime.utc(2026, 9, 10, 4));
  });

  test('formatTimestamptz stores TIMESTAMPTZ without changing wall-clock on read',
      () {
    final local = DateTime(2026, 9, 10, 7, 30);
    final encoded = ApiDateTime.formatTimestamptz(local);
    expect(encoded.endsWith('Z'), isTrue);
    expect(ApiDateTime.formatTimeOnly(local), '07:30:00');
    final roundTrip = ApiDateTime.parseTimestamptz(encoded);
    expect(roundTrip.year, 2026);
    expect(roundTrip.month, 9);
    expect(roundTrip.day, 10);
    expect(roundTrip.hour, 7);
    expect(roundTrip.minute, 30);
  });

  test('formatDateOnly and formatTimeOnly keep local calendar/wall-clock', () {
    final date = DateTime(2026, 9, 23, 22, 15, 30);
    expect(ApiDateTime.formatDateOnly(date), '2026-09-23');
    expect(ApiDateTime.formatTimeOnly(date), '22:15:30');
    expect(
      ApiDateTime.formatTimeOnly(DateTime(2026, 9, 23, 7, 30)),
      '07:30:00',
    );
  });
}
