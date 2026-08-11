import '../domain/vacation_model.dart';
import 'scheduling_month_utils.dart';

/// Accrued vacation days per month worked.
const double kVacationAccrualRatePerMonth = 1.7;

/// Result of vacation balance calculation for an employee.
class VacationBalanceResult {
  final bool hasEmploymentDate;
  final int monthsWorked;
  final double earnedRaw;
  final int earnedDays;
  final int usedDays;
  final int remainingDays;
  final double usageProgress;

  const VacationBalanceResult({
    required this.hasEmploymentDate,
    required this.monthsWorked,
    required this.earnedRaw,
    required this.earnedDays,
    required this.usedDays,
    required this.remainingDays,
    required this.usageProgress,
  });

  factory VacationBalanceResult.withoutEmploymentDate() {
    return const VacationBalanceResult(
      hasEmploymentDate: false,
      monthsWorked: 0,
      earnedRaw: 0,
      earnedDays: 0,
      usedDays: 0,
      remainingDays: 0,
      usageProgress: 0,
    );
  }
}

/// Calculates earned/used/remaining vacation days for an employee.
class VacationBalanceCalculator {
  VacationBalanceCalculator._();

  /// Rounds using the business rule: decimal >= 0.5 rounds up, else down.
  static int roundVacationDays(double value) {
    if (value <= 0) return 0;
    final whole = value.floor();
    final decimal = value - whole;
    return decimal >= 0.5 ? whole + 1 : whole;
  }

  /// Full calendar months worked from [employmentDate] through [asOf] (inclusive).
  static int monthsWorked(DateTime employmentDate, DateTime asOf) {
    final start = SchedulingMonthUtils.dateOnly(employmentDate);
    final end = SchedulingMonthUtils.dateOnly(asOf);
    if (end.isBefore(start)) return 0;

    var months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) {
      months -= 1;
    }
    return months.clamp(0, 9999);
  }

  static int approvedUsedDays(List<VacationModel> vacations) {
    return vacations
        .where((vacation) => vacation.status == 'approved')
        .fold(0, (sum, vacation) => sum + vacation.durationInDays);
  }

  static VacationBalanceResult calculate({
    required DateTime? employmentDate,
    required List<VacationModel> vacations,
    required DateTime asOf,
    double accrualRatePerMonth = kVacationAccrualRatePerMonth,
  }) {
    if (employmentDate == null) {
      return VacationBalanceResult.withoutEmploymentDate();
    }

    final months = monthsWorked(employmentDate, asOf);
    final earnedRaw = months * accrualRatePerMonth;
    final earnedDays = roundVacationDays(earnedRaw);
    final usedDays = approvedUsedDays(vacations);
    final remainingDays = (earnedDays - usedDays).clamp(0, earnedDays);
    final usageProgress = earnedDays > 0
        ? (usedDays / earnedDays).clamp(0.0, 1.0)
        : 0.0;

    return VacationBalanceResult(
      hasEmploymentDate: true,
      monthsWorked: months,
      earnedRaw: earnedRaw,
      earnedDays: earnedDays,
      usedDays: usedDays,
      remainingDays: remainingDays,
      usageProgress: usageProgress,
    );
  }
}
