import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_datetime.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/pwa/schedule_offline_cache.dart';
import '../../auth/data/users_repository.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/utils/location_catalog.dart';
import '../domain/shift_model.dart';
import '../utils/scheduling_month_utils.dart';

class ShiftRepository {
  ShiftRepository({
    ApiClient? apiClient,
    UsersRepository? usersRepository,
    LocationRepository? locationRepository,
    bool testMode = false,
  })  : _api = apiClient,
        _users = usersRepository,
        _locations = locationRepository,
        _testMode = testMode;

  @visibleForTesting
  ShiftRepository.test() : this(testMode: true);

  final ApiClient? _api;
  final UsersRepository? _users;
  final LocationRepository? _locations;
  final bool _testMode;

  ApiClient get _client {
    final api = _api;
    if (api == null) {
      throw const ApiException('Shifts API client is not configured');
    }
    return api;
  }

  UsersRepository get _usersRepo {
    final users = _users;
    if (users == null) {
      throw const ApiException('Shifts users repository is not configured');
    }
    return users;
  }

  /// GET /api/shifts returns all rows; filter user/month/location client-side.
  Future<List<ShiftModel>> getAllShifts() async {
    if (_testMode) return const [];
    final locations = _locations;
    if (locations == null) {
      throw const ApiException('Shifts API client is not configured');
    }

    final json = await _client.getJson('/api/shifts');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/shifts');
    }

    final catalog = await locations.getLocations();
    final usersByPostgresId = await _usersRepo.byPostgresId();
    final result = <ShiftModel>[];
    for (final item in json) {
      final map = Map<String, dynamic>.from(item as Map);
      final postgresUserId = map['user_id']?.toString() ?? '';
      final locationId = map['location_id']?.toString() ?? '';
      final user = usersByPostgresId[postgresUserId];
      final location = LocationCatalog.byId(catalog, locationId);
      if (user == null || location == null) continue;
      result.add(
        ShiftModel.fromApiJson(
          map,
          firebaseUid: user.uid,
          locationName: location.name,
          userName: user.name,
        ),
      );
    }
    return result;
  }

  Stream<List<ShiftModel>> getShiftsForMonth(DateTime month, String location) {
    return Stream.fromFuture(_shiftsForMonth(month, location: location));
  }

  Future<List<ShiftModel>> _shiftsForMonth(
    DateTime month, {
    String? location,
    String? userId,
  }) async {
    final all = await getAllShifts();
    return all.where((shift) {
      if (!SchedulingMonthUtils.isDateInMonth(shift.date, month)) return false;
      if (location != null && shift.location != location) return false;
      if (userId != null && shift.userId != userId) return false;
      return true;
    }).toList();
  }

  Stream<List<ShiftModel>> getUserShiftsForMonth(String userId, DateTime month) {
    return Stream.fromFuture(_userShiftsForMonth(userId, month));
  }

  Future<List<ShiftModel>> _userShiftsForMonth(
    String userId,
    DateTime month,
  ) async {
    final shifts = await _shiftsForMonth(month, userId: userId);
    if (kIsWeb) {
      await ScheduleOfflineCache().saveShifts(userId, shifts);
    }
    return shifts;
  }

  /// Last locally cached shifts (web offline fallback).
  Future<List<ShiftModel>> getCachedUserShifts(String userId) {
    return ScheduleOfflineCache().loadShifts(userId);
  }

  Future<Map<String, dynamic>> _toWriteBody(
    ShiftModel shift, {
    String? status,
    bool includeUserId = true,
  }) async {
    final user = await _usersRepo.findByFirebaseUid(shift.userId);
    final postgresId = user?.postgresId;
    if (postgresId == null || postgresId.isEmpty) {
      throw const ApiException('Unknown shift user');
    }
    return {
      if (includeUserId) 'user_id': postgresId,
      'location': shift.location,
      'work_date': ApiDateTime.formatDateOnly(shift.date),
      'start_at': ApiDateTime.formatTimestamptz(shift.startTime),
      'end_at': ApiDateTime.formatTimestamptz(shift.endTime),
      'type': shift.type,
      'status': status ?? shift.status,
    };
  }

  Future<void> createShift(ShiftModel shift) async {
    if (_testMode) return;
    await _client.postJson(
      '/api/shifts',
      body: await _toWriteBody(shift),
    );
  }

  Future<void> updateShift(ShiftModel shift) async {
    if (_testMode) return;
    if (shift.id.isEmpty) {
      throw const ApiException('Shift id is required');
    }
    await _client.patchJson(
      '/api/shifts/${shift.id}',
      body: await _toWriteBody(shift, includeUserId: false),
    );
  }

  Future<void> deleteShift(String shiftId) async {
    if (_testMode) return;
    if (shiftId.isEmpty) return;
    await _client.delete('/api/shifts/$shiftId');
  }

  Future<void> publishShifts(List<ShiftModel> shifts) async {
    if (_testMode) return;
    if (shifts.isEmpty) return;
    final payload = <Map<String, dynamic>>[];
    for (final shift in shifts) {
      payload.add(await _toWriteBody(shift, status: 'approved'));
    }
    await _client.postJson('/api/shifts/bulk', body: {'shifts': payload});
  }

  Future<List<ShiftModel>> getEmployeeShifts(String userId) async {
    if (_testMode) return const [];
    final all = await getAllShifts();
    return all.where((shift) => shift.userId == userId).toList();
  }

  Future<List<ShiftModel>> getShiftsForDay({
    required DateTime date,
    required String location,
    List<String> statuses = const ['approved', 'pending'],
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final all = await getAllShifts();
    return all.where((shift) {
      if (shift.location != location) return false;
      if (shift.date.year != day.year ||
          shift.date.month != day.month ||
          shift.date.day != day.day) {
        return false;
      }
      return statuses.contains(shift.status);
    }).toList();
  }

  Future<List<ShiftModel>> getShiftsForMonthLocation({
    required DateTime month,
    required String location,
    List<String> statuses = const ['approved', 'pending'],
  }) async {
    final shifts = await _shiftsForMonth(month, location: location);
    return shifts.where((shift) => statuses.contains(shift.status)).toList();
  }
}
