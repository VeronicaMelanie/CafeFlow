import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../data/availability_repository.dart';
import '../data/scheduling_config_repository.dart';
import '../data/scheduling_service.dart';
import '../data/shift_repository.dart';
import '../domain/availability_model.dart';
import '../domain/scheduling_config_model.dart';
import '../domain/shift_model.dart';
import '../utils/monthly_progress_calculator.dart';

final shiftRepositoryProvider = Provider<ShiftRepository>((ref) {
  return ShiftRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
  );
});

final schedulingConfigRepositoryProvider =
    Provider<SchedulingConfigRepository>((ref) {
  return SchedulingConfigRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

final schedulingServiceProvider = Provider<SchedulingService>((ref) {
  return SchedulingService(
    configRepository: ref.watch(schedulingConfigRepositoryProvider),
    availabilityRepository: ref.watch(availabilityRepositoryProvider),
    shiftRepository: ref.watch(shiftRepositoryProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

/// Month being edited on the availability calendar (defaults to next month).
final availabilityFocusedMonthProvider =
    StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month + 1, 1);
});

/// Active main employee bottom-navigation tab (0–3).
final employeeMainTabProvider = StateProvider<int>((ref) => 0);

final schedulingConfigForMonthProvider =
    StreamProvider.family<SchedulingConfigModel?, DateTime>((ref, month) {
  final user = ref.watch(currentUserProvider).value;
  final location = user?.primaryLocation;
  return ref
      .watch(schedulingConfigRepositoryProvider)
      .watchConfigForMonth(month, location: location);
});

final monthSchedulingAccessProvider =
    Provider.family<MonthSchedulingAccess, DateTime>((ref, month) {
  final config = ref.watch(schedulingConfigForMonthProvider(month)).value;
  return resolveMonthAccess(scheduleMonth: month, config: config);
});

final userAvailabilityForMonthProvider =
    StreamProvider.family<List<AvailabilityModel>, DateTime>((ref, month) {
  final profile = ref.watch(currentUserProvider);

  return profile.when(
    data: (user) {
      if (user == null) return Stream.value(const <AvailabilityModel>[]);
      return ref
          .read(availabilityRepositoryProvider)
          .watchUserAvailabilityForMonth(user.uid, month);
    },
    loading: () => Stream.value(const <AvailabilityModel>[]),
    error: (e, st) => Stream.error(e, st),
  );
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
  final month = ref.watch(selectedDateProvider);
  final user = ref.watch(currentUserProvider).value;
  final shiftsAsync = ref.watch(userShiftsProvider(userId));

  return shiftsAsync.whenData((shifts) {
    final targetHours = user?.monthlyTargetHours.toDouble() ?? 160.0;
    final progress = MonthlyProgressCalculator.calculate(
      shifts: shifts,
      vacations: const [],
      month: month,
      targetHours: targetHours,
    );
    return EmployeeStats(
      totalHours: progress.workedHours,
      targetHours: targetHours,
      shiftCount: shifts.where((s) => s.status == 'approved').length,
    );
  });
});

