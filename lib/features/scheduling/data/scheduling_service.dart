import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/domain/user_model.dart';
import '../domain/shift_model.dart';
import '../domain/availability_model.dart';
import '../domain/shift_type.dart';
import '../domain/scheduling_config_model.dart';
import '../utils/scheduling_month_utils.dart';

class SchedulingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SchedulingConfigModel> getConfig(DateTime month, String location) async {
    final collection = _firestore.collection('scheduling_config');
    final locationDocId = SchedulingMonthUtils.locationConfigDocId(
      month.year,
      month.month,
      location,
    );
    final globalDocId = SchedulingMonthUtils.globalConfigDocId(
      month.year,
      month.month,
    );

    final locationSnap = await collection.doc(locationDocId).get();
    if (locationSnap.exists) {
      return SchedulingConfigModel.fromMap(locationSnap.data()!, locationSnap.id);
    }

    final globalSnap = await collection.doc(globalDocId).get();
    if (globalSnap.exists) {
      return SchedulingConfigModel.fromMap(globalSnap.data()!, globalSnap.id);
    }

    return SchedulingConfigModel(
      id: locationDocId,
      year: month.year,
      month: month.month,
      location: location,
    );
  }

  /// Get real-time capacity for a specific date and location
  Future<Map<String, dynamic>> getCapacityInfo(
    DateTime date,
    String location,
  ) async {
    final config = await getConfig(date, location);
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final shiftsSnap = await _firestore
        .collection('shifts')
        .where('location', isEqualTo: location)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: ['approved', 'pending'])
        .get();

    final shifts = shiftsSnap.docs
        .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
        .toList();
    final totalHours = shifts.fold(0.0, (sum, s) => sum + s.durationInHours);
    final remainingHours = config.maxHoursPerDay - totalHours;
    final employeeCount = shifts.length;

    return {
      'totalHours': totalHours,
      'remainingHours': remainingHours,
      'employeeCount': employeeCount,
      'isFull': remainingHours <= 0,
      'isAlmostFull': remainingHours > 0 && remainingHours < 4,
      'maxEmployees': employeeCount >= config.maxEmployeesPerShift,
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
      // Check if the new shift overlaps with existing shifts
      final startOfDay = DateTime(
        shift.date.year,
        shift.date.month,
        shift.date.day,
      );
      final endOfDay = DateTime(
        shift.date.year,
        shift.date.month,
        shift.date.day,
        23,
        59,
        59,
      );

      final shiftsSnap = await _firestore
          .collection('shifts')
          .where('location', isEqualTo: shift.location)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['approved', 'pending'])
          .get();

      final shifts = shiftsSnap.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
      int concurrentEmployees = 0;

      for (var existingShift in shifts) {
        if (shift.startTime.isBefore(existingShift.endTime) &&
            shift.endTime.isAfter(existingShift.startTime)) {
          concurrentEmployees++;
        }
      }

      if (concurrentEmployees >= config.maxEmployeesPerShift) {
        return 'This time slot is full (max ${config.maxEmployeesPerShift} employees).';
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
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    // 1. Fetch all employees
    final employeesSnap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();
    final employees = employeesSnap.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();

    // 2. Fetch all availability for the month
    final availabilitySnap = await _firestore
        .collection('availability')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    final allAvailability = availabilitySnap.docs
        .map((doc) => AvailabilityModel.fromMap(doc.data(), doc.id))
        .where((a) => employees.any((e) => e.uid == a.userId)) // Filter valid userIds
        .where((a) => a.shiftType == AvailabilityShiftType.fullTime || a.isFullDay || (a.customStartTime != null && a.customEndTime != null)) // Filter valid custom times
        .toList();

    // 3. Keep track of assigned hours per employee
    Map<String, double> assignedHours = {for (var e in employees) e.uid: 0.0};

    // 4. Draft shifts list
    List<ShiftModel> draftShifts = [];

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

      // Locations to fill
      final locations = ['Gara', 'Avantgarden'];

      for (var location in locations) {
        double currentTotalHoursInLocation = 0.0;
        int employeesInLocation = 0;
        
        final config = await getConfig(month, location);

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
          if (employeesInLocation >= config.maxEmployeesPerShift) break; 
          if (currentTotalHoursInLocation >= config.maxHoursPerDay) break; 

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
          if (currentTotalHoursInLocation + shiftDuration > config.maxHoursPerDay) {
            shiftDuration = config.maxHoursPerDay - currentTotalHoursInLocation;
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

  /// Saves the draft shifts to Firestore as 'approved'
  Future<void> publishSchedule(List<ShiftModel> shifts) async {
    final batch = _firestore.batch();
    for (var shift in shifts) {
      final docRef = _firestore.collection('shifts').doc();
      batch.set(docRef, shift.toMap()..['status'] = 'approved');
    }
    await batch.commit();
  }

  /// Get underbooked days for a month (days with < 18 hours booked)
  Future<List<DateTime>> getUnderbookedDays(
    DateTime month,
    String location,
  ) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final shiftsSnap = await _firestore
        .collection('shifts')
        .where('location', isEqualTo: location)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .where('status', whereIn: ['approved', 'pending'])
        .get();

    final shifts = shiftsSnap.docs
        .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
        .toList();

    final Map<int, double> dailyHours = {};
    for (var shift in shifts) {
      dailyHours[shift.date.day] = (dailyHours[shift.date.day] ?? 0.0) + shift.durationInHours;
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

    final secondary =
        primaryLocation == 'Gara' ? 'Avantgarden' : 'Gara';
    final secondaryCapacity = await getCapacityInfo(date, secondary);
    final secondaryRemaining =
        secondaryCapacity['remainingHours'] as double;
    if (secondaryRemaining >= 4) return secondary;
    return null;
  }

  /// Stream capacity for real-time calendar updates.
  Stream<Map<String, dynamic>> watchCapacityInfo(
    DateTime date,
    String location,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _firestore
        .collection('shifts')
        .where('location', isEqualTo: location)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .where('status', whereIn: ['approved', 'pending'])
        .snapshots()
        .asyncMap((snapshot) async {
      final config = await getConfig(date, location);
      final shifts = snapshot.docs
          .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
          .toList();
      final totalHours = shifts.fold(0.0, (sum, s) => sum + s.durationInHours);
      final remainingHours = config.maxHoursPerDay - totalHours;
      return {
        'totalHours': totalHours,
        'remainingHours': remainingHours,
        'isFull': remainingHours <= 0,
        'isAlmostFull': remainingHours > 0 && remainingHours < 4,
      };
    });
  }

  /// Get fully occupied days for a month (days with max hours booked)
  Future<List<DateTime>> getFullyOccupiedDays(
    DateTime month,
    String location,
  ) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    final config = await getConfig(month, location);

    final shiftsSnap = await _firestore
        .collection('shifts')
        .where('location', isEqualTo: location)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .where('status', whereIn: ['approved', 'pending'])
        .get();

    final shifts = shiftsSnap.docs
        .map((doc) => ShiftModel.fromMap(doc.data(), doc.id))
        .toList();

    final Map<int, double> dailyHours = {};
    for (var shift in shifts) {
      dailyHours[shift.date.day] = (dailyHours[shift.date.day] ?? 0.0) + shift.durationInHours;
    }

    final fullyOccupiedDays = <DateTime>[];
    for (int day = 1; day <= endOfMonth.day; day++) {
      if ((dailyHours[day] ?? 0.0) >= config.maxHoursPerDay) {
        fullyOccupiedDays.add(DateTime(month.year, month.month, day));
      }
    }

    return fullyOccupiedDays;
  }
}
