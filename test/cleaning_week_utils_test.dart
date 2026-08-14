import 'package:fivetogo_scheduler/features/cleaning/utils/cleaning_week_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekIdFor uses ISO year and week number', () {
    expect(
      CleaningWeekUtils.weekIdFor(DateTime(2026, 8, 11)),
      '2026-W32',
    );
  });

  test('completed task remains in same week id across days', () {
    final monday = DateTime(2026, 8, 10);
    final wednesday = DateTime(2026, 8, 12);
    expect(
      CleaningWeekUtils.weekIdFor(monday),
      CleaningWeekUtils.weekIdFor(wednesday),
    );
  });

  test('completed task resets when week id changes', () {
    final lastWeek = DateTime(2026, 8, 9);
    final nextWeek = DateTime(2026, 8, 16);
    expect(
      CleaningWeekUtils.weekIdFor(lastWeek),
      isNot(CleaningWeekUtils.weekIdFor(nextWeek)),
    );
  });
}
