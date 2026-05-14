import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/domain/user_model.dart';
import '../domain/shift_model.dart';
import '../domain/availability_model.dart';

class SchedulingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generates a draft schedule for a specific month
  Future<List<ShiftModel>> generateDraftSchedule(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    // 1. Fetch all employees
    final employeesSnap = await _firestore.collection('users').where('role', isEqualTo: 'employee').get();
    final employees = employeesSnap.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();

    // 2. Fetch all availability for the month
    final availabilitySnap = await _firestore.collection('availability')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();
    
    final allAvailability = availabilitySnap.docs.map((doc) => AvailabilityModel.fromMap(doc.data(), doc.id)).toList();

    // 3. Keep track of assigned hours per employee
    Map<String, double> assignedHours = {for (var e in employees) e.uid: 0.0};
    
    // 4. Draft shifts list
    List<ShiftModel> draftShifts = [];

    // 5. Iterate through each day of the month
    for (int day = 1; day <= endOfMonth.day; day++) {
      final currentDate = DateTime(month.year, month.month, day);
      
      // Separate availability for this day
      final dailyAvailability = allAvailability.where((a) => 
        a.date.year == currentDate.year && 
        a.date.month == currentDate.month && 
        a.date.day == currentDate.day
      ).toList();

      // Locations to fill
      final locations = ['Gara', 'Avantgarden'];

      for (var location in locations) {
        double currentTotalHoursInLocation = 0.0;
        int employeesInLocation = 0;

        // Sort availability for this location:
        // Priority 1: Primary location matches
        // Priority 2: Underbooked employees (farthest from target)
        dailyAvailability.sort((a, b) {
          final empA = employees.firstWhere((e) => e.uid == a.userId);
          final empB = employees.firstWhere((e) => e.uid == b.userId);

          bool aPrimary = empA.primaryLocation == location;
          bool bPrimary = empB.primaryLocation == location;

          if (aPrimary && !bPrimary) return -1;
          if (!aPrimary && bPrimary) return 1;

          // Target balancing
          double aPercent = assignedHours[empA.uid]! / empA.monthlyTargetHours;
          double bPercent = assignedHours[empB.uid]! / empB.monthlyTargetHours;
          return aPercent.compareTo(bPercent);
        });

        for (var avail in dailyAvailability) {
          if (employeesInLocation >= 2) break; // Max 2 employees
          if (currentTotalHoursInLocation >= 22.0) break; // Max 22h per day

          final emp = employees.firstWhere((e) => e.uid == avail.userId);
          
          // Check if employee is already assigned to the other location today
          bool alreadyWorking = draftShifts.any((s) => s.userId == emp.uid && 
              s.date.day == currentDate.day && 
              s.date.month == currentDate.month);
          
          if (alreadyWorking) continue;

          double shiftDuration = avail.durationInHours;
          
          // Ensure we don't exceed 22h limit for location
          if (currentTotalHoursInLocation + shiftDuration > 22.0) {
            shiftDuration = 22.0 - currentTotalHoursInLocation;
          }

          if (shiftDuration <= 0) continue;

          // Create the shift
          DateTime startTime = avail.isFullDay 
              ? DateTime(currentDate.year, currentDate.month, currentDate.day, 7)
              : avail.customStartTime!;
          
          DateTime endTime = avail.isFullDay
              ? startTime.add(Duration(hours: 11))
              : avail.customEndTime!;

          draftShifts.add(ShiftModel(
            id: 'draft_${draftShifts.length}',
            userId: emp.uid,
            userName: emp.name,
            date: currentDate,
            startTime: startTime,
            endTime: endTime,
            type: avail.isFullDay ? 'FULL' : 'CUSTOM',
            location: location,
            status: 'pending',
          ));

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
}
