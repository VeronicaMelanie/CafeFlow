import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/shift_repository.dart';
import '../domain/shift_model.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository();
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());
final selectedLocationProvider = StateProvider<String>((ref) => 'Gara'); // or 'Avantgarden'

final shiftsForMonthProvider = StreamProvider.family<List<ShiftModel>, String>((ref, location) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(shiftRepositoryProvider).getShiftsForMonth(date, location);
});

final userShiftsProvider = StreamProvider.family<List<ShiftModel>, String>((ref, userId) {
  final date = ref.watch(selectedDateProvider);
  // We'll modify ShiftRepository to support this query
  return ref.watch(shiftRepositoryProvider).getUserShiftsForMonth(userId, date);
});

class EmployeeStats {
  final double totalHours;
  final double targetHours;
  final int shiftCount;

  EmployeeStats({required this.totalHours, required this.targetHours, required this.shiftCount});
}

final employeeStatsProvider = Provider.family<AsyncValue<EmployeeStats>, String>((ref, userId) {
  final shiftsAsync = ref.watch(userShiftsProvider(userId));
  
  return shiftsAsync.whenData((shifts) {
    final total = shifts.fold(0.0, (sum, shift) => sum + shift.durationInHours);
    return EmployeeStats(
      totalHours: total,
      targetHours: 160.0, // Default target
      shiftCount: shifts.length,
    );
  });
});

