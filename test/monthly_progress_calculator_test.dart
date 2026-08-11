import 'package:fivetogo_scheduler/features/scheduling/domain/shift_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/vacation_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/utils/monthly_progress_calculator.dart';
import 'package:fivetogo_scheduler/features/scheduling/utils/scheduling_month_utils.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftModel _shift({
  required DateTime date,
  double hours = 8,
  String status = 'approved',
}) {
  return ShiftModel(
    id: 'shift-${date.toIso8601String()}',
    userId: 'user-1',
    userName: 'Test User',
    date: date,
    startTime: date,
    endTime: date.add(Duration(minutes: (hours * 60).round())),
    type: 'FULL',
    location: 'Gara',
    status: status,
  );
}

VacationModel _vacation({
  required DateTime startDate,
  required DateTime endDate,
  String status = 'approved',
}) {
  return VacationModel(
    id: 'vac-${startDate.toIso8601String()}',
    userId: 'user-1',
    userName: 'Test User',
    startDate: startDate,
    endDate: endDate,
    status: status,
    requestedAt: startDate,
  );
}

void main() {
  const targetHours = 160.0;
  final august = DateTime(2026, 8, 1);
  final july = DateTime(2026, 7, 1);
  final september = DateTime(2026, 9, 1);

  group('MonthlyProgressCalculator', () {
    test('August calculation ignores July shift data', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: [
          _shift(date: DateTime(2026, 7, 15), hours: 11),
          _shift(date: DateTime(2026, 8, 10), hours: 8),
        ],
        vacations: const [],
        month: august,
        targetHours: targetHours,
      );

      expect(result.shiftHours, 8);
      expect(result.workedHours, 8);
      expect(result.remainingHours, 152);
      expect(result.progress, closeTo(8 / 160, 0.001));
    });

    test('September calculation ignores August shift data', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: [
          _shift(date: DateTime(2026, 8, 20), hours: 10),
          _shift(date: DateTime(2026, 9, 5), hours: 7),
        ],
        vacations: const [],
        month: september,
        targetHours: targetHours,
      );

      expect(result.shiftHours, 7);
      expect(result.workedHours, 7);
    });

    test('July vacation does not affect August progress', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: [_shift(date: DateTime(2026, 8, 12), hours: 8)],
        vacations: [
          _vacation(
            startDate: DateTime(2026, 7, 10),
            endDate: DateTime(2026, 7, 20),
          ),
        ],
        month: august,
        targetHours: targetHours,
      );

      expect(result.vacationHours, 0);
      expect(result.workedHours, 8);
      expect(result.remainingHours, 152);
    });

    test('July to August vacation counts only August overlap days', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: const [],
        vacations: [
          _vacation(
            startDate: DateTime(2026, 7, 28),
            endDate: DateTime(2026, 8, 5),
          ),
        ],
        month: august,
        targetHours: targetHours,
      );

      // Aug 1–5 inclusive = 5 days × 11h
      expect(result.vacationHours, 55);
      expect(result.workedHours, 55);
      expect(result.remainingHours, 105);
    });

    test('changing selected month recalculates from that month only', () {
      final shifts = [
        _shift(date: DateTime(2026, 7, 2), hours: 11),
        _shift(date: DateTime(2026, 8, 2), hours: 8),
        _shift(date: DateTime(2026, 9, 2), hours: 9),
      ];
      final vacations = [
        _vacation(
          startDate: DateTime(2026, 7, 28),
          endDate: DateTime(2026, 8, 3),
        ),
      ];

      final julyResult = MonthlyProgressCalculator.calculate(
        shifts: shifts,
        vacations: vacations,
        month: july,
        targetHours: targetHours,
      );
      final augustResult = MonthlyProgressCalculator.calculate(
        shifts: shifts,
        vacations: vacations,
        month: august,
        targetHours: targetHours,
      );
      final septemberResult = MonthlyProgressCalculator.calculate(
        shifts: shifts,
        vacations: vacations,
        month: september,
        targetHours: targetHours,
      );

      expect(julyResult.shiftHours, 11);
      expect(julyResult.vacationHours, 44); // Jul 28–31 = 4 days
      expect(julyResult.workedHours, 55);

      expect(augustResult.shiftHours, 8);
      expect(augustResult.vacationHours, 33); // Aug 1–3 = 3 days
      expect(augustResult.workedHours, 41);

      expect(septemberResult.shiftHours, 9);
      expect(septemberResult.vacationHours, 0);
      expect(septemberResult.workedHours, 9);
    });

    test('target, worked, remaining and percentage are month-scoped', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: [
          _shift(date: DateTime(2026, 8, 4), hours: 10),
          _shift(date: DateTime(2026, 8, 18), hours: 6),
          _shift(date: DateTime(2026, 7, 30), hours: 11),
        ],
        vacations: [
          _vacation(
            startDate: DateTime(2026, 8, 25),
            endDate: DateTime(2026, 8, 26),
          ),
        ],
        month: august,
        targetHours: targetHours,
      );

      expect(result.targetHours, targetHours);
      expect(result.shiftHours, 16);
      expect(result.vacationHours, 22); // 2 days × 11h
      expect(result.workedHours, 38);
      expect(result.remainingHours, 122);
      expect(result.progress, closeTo(38 / 160, 0.001));
    });

    test('ignores non-approved shifts and vacations', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: [
          _shift(date: DateTime(2026, 8, 6), hours: 8, status: 'pending'),
          _shift(date: DateTime(2026, 8, 7), hours: 9, status: 'approved'),
        ],
        vacations: [
          _vacation(
            startDate: DateTime(2026, 8, 10),
            endDate: DateTime(2026, 8, 11),
            status: 'pending',
          ),
        ],
        month: august,
        targetHours: targetHours,
      );

      expect(result.shiftHours, 9);
      expect(result.vacationHours, 0);
      expect(result.workedHours, 9);
    });

    test('defensively excludes shifts outside queried month', () {
      final result = MonthlyProgressCalculator.calculate(
        shifts: [
          _shift(date: DateTime(2026, 8, 8), hours: 8),
          _shift(date: DateTime(2026, 9, 1), hours: 11),
        ],
        vacations: const [],
        month: august,
        targetHours: targetHours,
      );

      expect(result.shiftHours, 8);
    });
  });

  group('SchedulingMonthUtils month boundaries', () {
    test('monthStart and monthEnd bound August 2026', () {
      final start = SchedulingMonthUtils.monthStart(august);
      final end = SchedulingMonthUtils.monthEnd(august);

      expect(start, DateTime(2026, 8, 1));
      expect(end, DateTime(2026, 8, 31, 23, 59, 59));
    });

    test('vacationDaysInMonth returns zero when vacation is outside month', () {
      final days = SchedulingMonthUtils.vacationDaysInMonth(
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
        august,
      );

      expect(days, 0);
    });
  });
}
