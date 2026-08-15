import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/users_repository.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/utils/location_catalog.dart';
import '../domain/scheduling_config_model.dart';
import '../utils/scheduling_month_utils.dart';

class SchedulingConfigRepository {
  SchedulingConfigRepository({
    ApiClient? apiClient,
    UsersRepository? usersRepository,
    LocationRepository? locationRepository,
  })  : _api = apiClient,
        _users = usersRepository,
        _locations = locationRepository;

  final ApiClient? _api;
  final UsersRepository? _users;
  final LocationRepository? _locations;

  ApiClient get _client {
    final api = _api;
    if (api == null) {
      throw const ApiException('Scheduling config API client is not configured');
    }
    return api;
  }

  /// Client-side year/month/location filter: GET /api/scheduling returns all rows.
  Stream<SchedulingConfigModel?> watchConfigForMonth(
    DateTime month, {
    String? location,
  }) {
    return Stream.fromFuture(getConfigForMonth(month, location: location));
  }

  Future<SchedulingConfigModel?> getConfigForMonth(
    DateTime month, {
    String? location,
  }) async {
    final configs = await listConfigs();
    final year = month.year;
    final monthNum = month.month;
    final forMonth = configs
        .where((config) => config.year == year && config.month == monthNum)
        .toList();

    if (location != null && location.isNotEmpty) {
      for (final config in forMonth) {
        if (config.location == location) return config;
      }
    }
    for (final config in forMonth) {
      if (config.isGlobal) return config;
    }
    return null;
  }

  /// Exact year+month+location match. Does not fall back to a global row.
  Future<SchedulingConfigModel?> findExactConfig({
    required int year,
    required int month,
    String? location,
  }) async {
    final configs = await listConfigs();
    final locationName = location != null && location.isNotEmpty ? location : null;
    for (final config in configs) {
      if (config.year != year || config.month != month) continue;
      if (locationName == null) {
        if (config.isGlobal) return config;
      } else if (config.location == locationName) {
        return config;
      }
    }
    return null;
  }

  Future<List<SchedulingConfigModel>> listConfigs() async {
    final users = _users;
    final locations = _locations;
    if (users == null || locations == null) {
      throw const ApiException('Scheduling config API client is not configured');
    }

    final json = await _client.getJson('/api/scheduling');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/scheduling');
    }

    final catalog = await locations.getLocations();
    final usersByPostgresId = await users.byPostgresId();

    final result = <SchedulingConfigModel>[];
    for (final item in json) {
      final map = Map<String, dynamic>.from(item as Map);
      final locationId = map['location_id']?.toString();
      String? locationName;
      if (locationId != null && locationId.isNotEmpty) {
        locationName = LocationCatalog.byId(catalog, locationId)?.name;
        // Unmapped location_id must not be treated as a global (null) config.
        if (locationName == null) continue;
      }
      final enabledById = map['enabled_by']?.toString();
      result.add(
        SchedulingConfigModel.fromApiJson(
          map,
          locationName: locationName,
          enabledByFirebaseUid: enabledById == null || enabledById.isEmpty
              ? null
              : usersByPostgresId[enabledById]?.uid,
        ),
      );
    }
    return result;
  }

  Future<void> setSchedulingEnabled({
    required int year,
    required int month,
    String? location,
    required bool enabled,
    required String adminUid,
  }) async {
    if (adminUid.isEmpty) {
      throw const ApiException('Admin user is required');
    }
    await _upsertConfig(
      year: year,
      month: month,
      location: location,
      payload: {
        'scheduling_enabled': enabled,
        'locked_month': false,
      },
    );
  }

  Future<void> setMonthLocked({
    required int year,
    required int month,
    required bool locked,
    String? location,
  }) async {
    await _upsertConfig(
      year: year,
      month: month,
      location: location,
      payload: {'locked_month': locked},
    );
  }

  Future<void> _upsertConfig({
    required int year,
    required int month,
    String? location,
    required Map<String, dynamic> payload,
  }) async {
    final existing = await findExactConfig(
      year: year,
      month: month,
      location: location,
    );
    if (existing != null) {
      await _client.patchJson(
        '/api/scheduling/${existing.id}',
        body: payload,
      );
      return;
    }

    await _client.postJson(
      '/api/scheduling',
      body: {
        'year': year,
        'month': month,
        if (location != null && location.isNotEmpty) 'location': location,
        ...payload,
      },
    );
  }

  Future<List<SchedulingConfigModel>> listConfigsForYear(int year) async {
    final configs = await listConfigs();
    return configs.where((config) => config.year == year).toList();
  }
}

/// Resolved state for employee availability UI.
class MonthSchedulingAccess {
  final bool calendarMonthLocked;
  final bool adminLockedMonth;
  final bool schedulingEnabled;
  final bool canEdit;

  const MonthSchedulingAccess({
    required this.calendarMonthLocked,
    required this.adminLockedMonth,
    required this.schedulingEnabled,
    required this.canEdit,
  });

  String? get bannerMessage {
    if (calendarMonthLocked || adminLockedMonth) {
      return 'Scheduling for this month is locked.';
    }
    if (!schedulingEnabled) {
      return 'Scheduling has not been opened yet. Please wait for your manager.';
    }
    return null;
  }
}

MonthSchedulingAccess resolveMonthAccess({
  required DateTime scheduleMonth,
  SchedulingConfigModel? config,
  DateTime? now,
}) {
  final calendarLocked =
      !SchedulingMonthUtils.isMonthEditable(scheduleMonth, now);
  final adminOpen = config?.schedulingEnabled ?? false;
  final adminLocked = config?.lockedMonth ?? false;

  return MonthSchedulingAccess(
    calendarMonthLocked: calendarLocked,
    adminLockedMonth: adminLocked,
    schedulingEnabled: adminOpen,
    canEdit: !calendarLocked && !adminLocked && adminOpen,
  );
}
