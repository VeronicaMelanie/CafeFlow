import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/widgets/shift_type_selection_sheet.dart';

void main() {
  final day = DateTime(2026, 9, 8);

  group('validateCustomHoursSelection', () {
    test('accepts valid custom hours', () {
      expect(
        validateCustomHoursSelection(
          day: day,
          start: const TimeOfDay(hour: 16, minute: 0),
          end: const TimeOfDay(hour: 18, minute: 0),
        ),
        isTrue,
      );
    });

    test('rejects end time before or equal to start time', () {
      expect(
        validateCustomHoursSelection(
          day: day,
          start: const TimeOfDay(hour: 16, minute: 0),
          end: const TimeOfDay(hour: 16, minute: 0),
        ),
        isFalse,
      );
      expect(
        validateCustomHoursSelection(
          day: day,
          start: const TimeOfDay(hour: 16, minute: 0),
          end: const TimeOfDay(hour: 15, minute: 0),
        ),
        isFalse,
      );
    });

    test('rejects hours outside shop window', () {
      expect(
        validateCustomHoursSelection(
          day: day,
          start: const TimeOfDay(hour: 6, minute: 0),
          end: const TimeOfDay(hour: 10, minute: 0),
        ),
        isFalse,
      );
      expect(
        validateCustomHoursSelection(
          day: day,
          start: const TimeOfDay(hour: 10, minute: 0),
          end: const TimeOfDay(hour: 19, minute: 0),
        ),
        isFalse,
      );
    });
  });
}
