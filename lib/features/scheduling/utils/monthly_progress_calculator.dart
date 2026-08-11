import '../domain/shift_model.dart';
import '../domain/vacation_model.dart';
import 'scheduling_month_utils.dart';

/// Month-scoped monthly progress metrics for an employee schedule.
class MonthlyProgressResult {
  final double shiftHours;
  final double vacationHours;
  final double workedHours;
  final double targetHours;
  final double remainingHours;
  final double progress;

  const MonthlyProgressResult({
    required this.shiftHours,
    required this.vacationHours,
    required this.workedHours,
    required this.targetHours,
    required this.remainingHours,
    required this.progress,
  });
}

/// Calculates monthly progress strictly from a single month's schedule.
class MonthlyProgressCalculator {
  MonthlyProgressCalculator._();

  static MonthlyProgressResult calculate({
    required List<ShiftModel> shifts,
    required List<VacationModel> vacations,
    required DateTime month,
    required double targetHours,
    double hoursPerVacationDay = SchedulingMonthUtils.fullShiftHours,
  }) {
    final shiftHours = shifts
        .where(
          (shift) =>
              shift.status == 'approved' &&
              SchedulingMonthUtils.isDateInMonth(shift.date, month),
        )
        .fold(0.0, (sum, shift) => sum + shift.durationInHours);

    var vacationHours = 0.0;
    for (final vacation in vacations.where((v) => v.status == 'approved')) {
      final days = SchedulingMonthUtils.vacationDaysInMonth(
        vacation.startDate,
        vacation.endDate,
        month,
      );
      vacationHours += days * hoursPerVacationDay;
    }

    final workedHours = shiftHours + vacationHours;
    final remainingHours =
        (targetHours - workedHours).clamp(0.0, targetHours);
    final progress = targetHours > 0
        ? (workedHours / targetHours).clamp(0.0, 1.0)
        : 0.0;

    return MonthlyProgressResult(
      shiftHours: shiftHours,
      vacationHours: vacationHours,
      workedHours: workedHours,
      targetHours: targetHours,
      remainingHours: remainingHours,
      progress: progress,
    );
  }
}
