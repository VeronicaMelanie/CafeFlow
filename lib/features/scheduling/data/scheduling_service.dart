import '../../auth/data/users_repository.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/utils/location_catalog.dart';
import '../domain/scheduling_config_model.dart';
import '../domain/shift_model.dart';
import '../domain/shift_type.dart';
import '../utils/scheduling_month_utils.dart';
import 'availability_repository.dart';
import 'scheduling_config_repository.dart';
import 'shift_repository.dart';

class SchedulingService {
  SchedulingService({
    required SchedulingConfigRepository configRepository,
    required AvailabilityRepository availabilityRepository,
    required ShiftRepository shiftRepository,
    required UsersRepository usersRepository,
    required LocationRepository locationRepository,
  })  : _configRepository = configRepository,
        _availabilityRepository = availabilityRepository,
        _shiftRepository = shiftRepository,
        _usersRepository = usersRepository,
        _locationRepository = locationRepository;

  final SchedulingConfigRepository _configRepository;
  final AvailabilityRepository _availabilityRepository;
  final ShiftRepository _shiftRepository;
  final UsersRepository _usersRepository;
  final LocationRepository _locationRepository;

  /// Operational fallback when the API omits a limit. Not an invented API value.
  double _maxHoursPerDay(SchedulingConfigModel config) =>
      config.maxHoursPerDay ?? 22.0;

  /// Operational fallback when the API omits a limit. Not an invented API value.
  int _maxEmployeesPerShift(SchedulingConfigModel config) =>
      config.maxEmployeesPerShift ?? 2;

  Future<SchedulingConfigModel> getConfig(DateTime month, String location) async {
    final config = await _configRepository.getConfigForMonth(
      month,
      location: location,
    );
    if (config != null) return config;

    return SchedulingConfigModel(
      id: SchedulingMonthUtils.locationConfigDocId(
        month.year,
        month.month,
        location,
      ),
      year: month.year,
      month: month.month,
      location: location,
    );
  }

  /// Get capacity for a specific date and location.
  Future<Map<String, dynamic>> getCapacityInfo(
    DateTime date,
    String location,
  ) async {
    final config = await getConfig(date, location);
    final shifts = await _shiftRepository.getShiftsForDay(
      date: date,
      location: location,
    );
    final totalHours = shifts.fold(0.0, (sum, s) => sum + s.durationInHours);
    final remainingHours = _maxHoursPerDay(config) - totalHours;
    final employeeCount = shifts.length;

    return {
      'totalHours': totalHours,
      'remainingHours': remainingHours,
      'employeeCount': employeeCount,
      'isFull': remainingHours <= 0,
      'isAlmostFull': remainingHours > 0 && remainingHours < 4,
      'maxEmployees': employeeCount >= _maxEmployeesPerShift(config),
    };
  }

  /// Check if a shift can be booked without exceeding capacity
  Future<String?> validateShiftBooking(ShiftModel shift) async {
    final config = await getConfig(shift.date, shift.location);
    final capacity = await getCapacityInfo(shift.date, shift.location);

    if (capacity['isFull'] == true) {
      return 'This location is fully booked for this day.';
    }

    if (capacity['maxEmployees'] == true) {
      final shifts = await _shiftRepository.getShiftsForDay(
        date: shift.date,
        location: shift.location,
      );
      int concurrentEmployees = 0;

      for (var existingShift in shifts) {
        if (shift.startTime.isBefore(existingShift.endTime) &&
            shift.endTime.isAfter(existingShift.startTime)) {
          concurrentEmployees++;
        }
      }

      if (concurrentEmployees >= _maxEmployeesPerShift(config)) {
        return 'This time slot is full (max ${_maxEmployeesPerShift(config)} employees).';
      }
    }

    final remainingHours = capacity['remainingHours'] as double;
    if (remainingHours < shift.durationInHours) {
      return 'Not enough hours available. Only ${remainingHours.toStringAsFixed(1)}h remaining.';
    }

    return null; // Valid
  }

  /// Generates a draft schedule for a specific month
  Future<List<ShiftModel>> generateDraftSchedule(DateTime month) async {
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    // 1. Fetch all employees
    final employees = await _usersRepository.getEmployees();

    // 2. Fetch all availability for the month (API read, client-side month filter)
    final allAvailability = (await _availabilityRepository
            .getAvailabilityForMonth(month))
        .where((a) => employees.any((e) => e.uid == a.userId))
        .where(
          (a) =>
              a.shiftType == AvailabilityShiftType.fullTime ||
              a.isFullDay ||
              (a.customStartTime != null && a.customEndTime != null),
        )
        .toList();

    // 3. Keep track of assigned hours per employee
    Map<String, double> assignedHours = {for (var e in employees) e.uid: 0.0};

    // 4. Draft shifts list
    List<ShiftModel> draftShifts = [];
    final locations = LocationCatalog.names(
      await _locationRepository.getLocations(),
    );

    // 5. Iterate through each day of the month
    for (int day = 1; day <= endOfMonth.day; day++) {
      final currentDate = DateTime(month.year, month.month, day);

      // Separate availability for this day
      final dailyAvailability = allAvailability
          .where(
            (a) =>
                a.date.year == currentDate.year &&
                a.date.month == currentDate.month &&
                a.date.day == currentDate.day,
          )
          .toList();

      for (var location in locations) {
        double currentTotalHoursInLocation = 0.0;
        int employeesInLocation = 0;

        final config = await getConfig(month, location);
        final maxHours = _maxHoursPerDay(config);
        final maxEmployees = _maxEmployeesPerShift(config);

        // Sort availability for this location:
        dailyAvailability.sort((a, b) {
          final fcfs = a.fcfsSortKey.compareTo(b.fcfsSortKey);
          if (fcfs != 0) return fcfs;

          final empA = employees.firstWhere((e) => e.uid == a.userId);
          final empB = employees.firstWhere((e) => e.uid == b.userId);

          final aPrimary = empA.primaryLocation == location;
          final bPrimary = empB.primaryLocation == location;

          if (aPrimary && !bPrimary) return -1;
          if (!aPrimary && bPrimary) return 1;

          final aPercent = assignedHours[empA.uid]! / empA.monthlyTargetHours;
          final bPercent = assignedHours[empB.uid]! / empB.monthlyTargetHours;
          return aPercent.compareTo(bPercent);
        });

        for (var avail in dailyAvailability) {
          if (employeesInLocation >= maxEmployees) break;
          if (currentTotalHoursInLocation >= maxHours) break;

          final emp = employees.where((e) => e.uid == avail.userId).firstOrNull;
          if (emp == null) continue;

          // Check if employee is already assigned to the other location today
          bool alreadyWorking = draftShifts.any(
            (s) =>
                s.userId == emp.uid &&
                s.date.day == currentDate.day &&
                s.date.month == currentDate.month,
          );

          if (alreadyWorking) continue;

          double shiftDuration = avail.durationInHours;

          // Ensure we don't exceed max limit for location
          if (currentTotalHoursInLocation + shiftDuration > maxHours) {
            shiftDuration = maxHours - currentTotalHoursInLocation;
          }

          if (shiftDuration <= 0) continue;

          // Create the shift
          final isFullTime = avail.shiftType == AvailabilityShiftType.fullTime ||
              avail.isFullDay;

          final DateTime startTime = isFullTime
              ? DateTime(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day,
                  7,
                )
              : avail.customStartTime!; // Safe because filtered above

          final DateTime endTime = isFullTime
              ? startTime.add(const Duration(hours: 11))
              : avail.customEndTime!; // Safe because filtered above

          draftShifts.add(
            ShiftModel(
              id: 'draft_${draftShifts.length}',
              userId: emp.uid,
              userName: emp.name,
              date: currentDate,
              startTime: startTime,
              endTime: endTime,
              type: isFullTime ? 'FULL' : 'CUSTOM',
              location: location,
              status: 'pending',
            ),
          );

          currentTotalHoursInLocation += shiftDuration;
          assignedHours[emp.uid] = assignedHours[emp.uid]! + shiftDuration;
          employeesInLocation++;
        }
      }
    }

    return draftShifts;
  }

  /// Saves the draft shifts through the shifts API as 'approved'.
  Future<void> publishSchedule(List<ShiftModel> shifts) async {
    await _shiftRepository.publishShifts(shifts);
  }

  /// Get underbooked days for a month (days with < 18 hours booked)
  Future<List<DateTime>> getUnderbookedDays(
    DateTime month,
    String location,
  ) async {
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final shifts = await _shiftRepository.getShiftsForMonthLocation(
      month: month,
      location: location,
    );

    final Map<int, double> dailyHours = {};
    for (var shift in shifts) {
      dailyHours[shift.date.day] =
          (dailyHours[shift.date.day] ?? 0.0) + shift.durationInHours;
    }

    final underbookedDays = <DateTime>[];
    for (int day = 1; day <= endOfMonth.day; day++) {
      if ((dailyHours[day] ?? 0.0) < 18.0) {
        underbookedDays.add(DateTime(month.year, month.month, day));
      }
    }

    return underbookedDays;
  }

  /// When primary location has < 4h left, suggest the other location if it has capacity.
  Future<String?> suggestSecondaryLocation(
    DateTime date,
    String primaryLocation,
  ) async {
    final primary = await getCapacityInfo(date, primaryLocation);
    final remaining = primary['remainingHours'] as double;
    if (remaining >= 4) return null;

    final secondary = LocationCatalog.otherName(
      await _locationRepository.getLocations(),
      primaryLocation,
    );
    if (secondary == null) return null;
    final secondaryCapacity = await getCapacityInfo(date, secondary);
    final secondaryRemaining =
        secondaryCapacity['remainingHours'] as double;
    if (secondaryRemaining >= 4) return secondary;
    return null;
  }

  /// One-shot capacity for calendar chips. API has no Firestore realtime.
  Stream<Map<String, dynamic>> watchCapacityInfo(
    DateTime date,
    String location,
  ) {
    return Stream.fromFuture(getCapacityInfo(date, location));
  }

  /// Get fully occupied days for a month (days with max hours booked)
  Future<List<DateTime>> getFullyOccupiedDays(
    DateTime month,
    String location,
  ) async {
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final config = await getConfig(month, location);
    final maxHours = _maxHoursPerDay(config);
    final shifts = await _shiftRepository.getShiftsForMonthLocation(
      month: month,
      location: location,
    );

    final Map<int, double> dailyHours = {};
    for (var shift in shifts) {
      dailyHours[shift.date.day] =
          (dailyHours[shift.date.day] ?? 0.0) + shift.durationInHours;
    }

    final fullyOccupiedDays = <DateTime>[];
    for (int day = 1; day <= endOfMonth.day; day++) {
      if ((dailyHours[day] ?? 0.0) >= maxHours) {
        fullyOccupiedDays.add(DateTime(month.year, month.month, day));
      }
    }

    return fullyOccupiedDays;
  }
}
