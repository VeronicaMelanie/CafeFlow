import '../../../core/api/api_client.dart';
import '../../../core/api/api_datetime.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/users_repository.dart';
import '../domain/availability_model.dart';
import '../domain/shift_type.dart';
import '../utils/scheduling_month_utils.dart';

class AvailabilityRepository {
  AvailabilityRepository({
    ApiClient? apiClient,
    UsersRepository? usersRepository,
  })  : _api = apiClient,
        _users = usersRepository;

  final ApiClient? _api;
  final UsersRepository? _users;

  ApiClient get _client {
    final api = _api;
    if (api == null) {
      throw const ApiException('Availability API client is not configured');
    }
    return api;
  }

  UsersRepository get _usersRepo {
    final users = _users;
    if (users == null) {
      throw const ApiException('Availability users repository is not configured');
    }
    return users;
  }

  /// GET /api/availability returns all rows; filter user/month/day client-side.
  Future<List<AvailabilityModel>> getAllAvailability() async {
    final json = await _client.getJson('/api/availability');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/availability');
    }

    final usersByPostgresId = await _usersRepo.byPostgresId();
    final result = <AvailabilityModel>[];
    for (final item in json) {
      final map = Map<String, dynamic>.from(item as Map);
      final postgresUserId = map['user_id']?.toString() ?? '';
      final user = usersByPostgresId[postgresUserId];
      if (user == null) continue;
      result.add(AvailabilityModel.fromApiJson(map, firebaseUid: user.uid));
    }
    return result;
  }

  Stream<List<AvailabilityModel>> watchUserAvailabilityForMonth(
    String userId,
    DateTime month,
  ) {
    return Stream.fromFuture(getUserAvailabilityForMonth(userId, month));
  }

  Future<List<AvailabilityModel>> getUserAvailabilityForMonth(
    String userId,
    DateTime month,
  ) async {
    final all = await getAllAvailability();
    return all
        .where(
          (entry) =>
              entry.userId == userId &&
              SchedulingMonthUtils.isDateInMonth(entry.date, month),
        )
        .toList();
  }

  Future<List<AvailabilityModel>> getAvailabilityForMonth(DateTime month) async {
    final all = await getAllAvailability();
    return all
        .where((entry) => SchedulingMonthUtils.isDateInMonth(entry.date, month))
        .toList();
  }

  Future<AvailabilityModel?> getForUserOnDay(String userId, DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    final all = await getAllAvailability();
    for (final entry in all) {
      if (entry.userId == userId &&
          entry.date.year == normalized.year &&
          entry.date.month == normalized.month &&
          entry.date.day == normalized.day) {
        return entry;
      }
    }
    return null;
  }

  Future<String?> validatePartTimeHours({
    required DateTime day,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!end.isAfter(start)) {
      return 'End time must be after start time.';
    }

    final open = DateTime(
      day.year,
      day.month,
      day.day,
      SchedulingMonthUtils.shopOpenHour,
    );
    final close = DateTime(
      day.year,
      day.month,
      day.day,
      SchedulingMonthUtils.shopCloseHour,
    );

    if (start.isBefore(open) || end.isAfter(close)) {
      return 'Hours must be between 07:00 and 18:00.';
    }

    final durationHours = end.difference(start).inMinutes / 60.0;
    if (durationHours <= 0) {
      return 'Invalid time interval.';
    }

    return null;
  }

  Map<String, dynamic> _writePayload({
    required DateTime day,
    required AvailabilityShiftType shiftType,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final normalized = DateTime(day.year, day.month, day.day);
    final isCustom = shiftType == AvailabilityShiftType.customHours;
    return {
      'work_date': ApiDateTime.formatDateOnly(normalized),
      'shift_type': shiftType.firestoreValue,
      'custom_start_time':
          isCustom && customStart != null
              ? ApiDateTime.formatTimeOnly(customStart)
              : null,
      'custom_end_time':
          isCustom && customEnd != null
              ? ApiDateTime.formatTimeOnly(customEnd)
              : null,
    };
  }

  /// POST create or PATCH update. Owner is the Firebase token, not [userId].
  Future<void> saveAvailability({
    required String userId,
    required DateTime day,
    required AvailabilityShiftType shiftType,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final normalized = DateTime(day.year, day.month, day.day);

    DateTime? start;
    DateTime? end;
    if (shiftType == AvailabilityShiftType.customHours) {
      start = customStart;
      end = customEnd;
    }

    final payload = _writePayload(
      day: normalized,
      shiftType: shiftType,
      customStart: start,
      customEnd: end,
    );
    final existing = await getForUserOnDay(userId, normalized);

    if (existing != null && existing.id.isNotEmpty) {
      await _client.patchJson(
        '/api/availability/${existing.id}',
        body: payload,
      );
      return;
    }

    await _client.postJson('/api/availability', body: payload);
  }

  Future<void> deleteAvailability(String docId) async {
    if (docId.isEmpty) return;
    await _client.delete('/api/availability/$docId');
  }

  Future<void> deleteForUserOnDay(String userId, DateTime day) async {
    final existing = await getForUserOnDay(userId, day);
    if (existing != null) {
      await deleteAvailability(existing.id);
    }
  }

  /// Total hours the user has submitted for [month] (availability, not assigned shifts).
  double totalSubmittedHours(List<AvailabilityModel> entries) {
    return entries.fold(0.0, (sum, e) => sum + e.durationInHours);
  }
}
