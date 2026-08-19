import '../../../core/api/api_client.dart';
import '../../../core/api/api_datetime.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/ttl_cache.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/utils/location_catalog.dart';
import '../domain/user_model.dart';

class UsersRepository {
  UsersRepository({
    required ApiClient apiClient,
    required LocationRepository locationRepository,
  })  : _api = apiClient,
        _locations = locationRepository;

  final ApiClient _api;
  final LocationRepository _locations;
  final TtlCache<List<UserModel>> _cache = TtlCache();

  Future<List<UserModel>> getUsers() {
    return _cache.getOrLoad(_fetchUsers);
  }

  void invalidateCache() => _cache.invalidate();

  Future<List<UserModel>> _fetchUsers() async {
    final json = await _api.getJson('/api/users');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/users');
    }
    final names = await _catalogLocationNames();

    return json
        .map(
          (item) => UserModel.fromApiJson(
            Map<String, dynamic>.from(item as Map),
            primaryLocation: names.primary,
            secondaryLocation: names.secondary,
          ),
        )
        .toList();
  }

  Future<List<UserModel>> getEmployees() async {
    final users = await getUsers();
    return users.where((user) => user.role == 'employee').toList();
  }

  Future<UserModel?> findByFirebaseUid(String firebaseUid) async {
    final users = await getUsers();
    for (final user in users) {
      if (user.uid == firebaseUid) return user;
    }
    return null;
  }

  Future<Map<String, UserModel>> byPostgresId() async {
    final users = await getUsers();
    final map = <String, UserModel>{};
    for (final user in users) {
      final postgresId = user.postgresId;
      if (postgresId != null && postgresId.isNotEmpty) {
        map[postgresId] = user;
      }
    }
    return map;
  }

  /// Creates the authenticated user's PostgreSQL profile if missing.
  /// Identity comes from the Firebase ID token, never from a client UID.
  Future<UserModel> ensureCurrentUser({String? name}) async {
    final body = <String, dynamic>{};
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      body['name'] = trimmed;
    }
    final json = await _api.postJson(
      '/api/users',
      body: body.isEmpty ? <String, dynamic>{} : body,
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from POST /api/users');
    }
    _cache.invalidate();
    return _userFromApiJson(Map<String, dynamic>.from(json));
  }

  Future<UserModel> updateUser({
    required String postgresId,
    String? name,
    int? monthlyTargetHours,
    String? contractType,
    bool? needsContractType,
    DateTime? employmentDate,
    bool clearEmploymentDate = false,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (monthlyTargetHours != null) {
      body['monthly_target_hours'] = monthlyTargetHours;
    }
    if (contractType != null) body['contract_type'] = contractType;
    if (needsContractType != null) {
      body['needs_contract_type'] = needsContractType;
    }
    if (clearEmploymentDate) {
      body['employment_started_on'] = null;
    } else if (employmentDate != null) {
      body['employment_started_on'] = ApiDateTime.formatDateOnly(employmentDate);
    }

    final json = await _api.patchJson('/api/users/$postgresId', body: body);
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from PATCH /api/users');
    }
    _cache.invalidate();
    return _userFromApiJson(Map<String, dynamic>.from(json));
  }

  Future<void> setContractType({
    required String firebaseUid,
    required String contractType,
  }) async {
    final user = await findByFirebaseUid(firebaseUid);
    final postgresId = user?.postgresId;
    if (postgresId == null || postgresId.isEmpty) {
      throw const ApiException('PostgreSQL user id is missing');
    }
    await updateUser(
      postgresId: postgresId,
      contractType: contractType,
      needsContractType: false,
    );
  }

  Future<UserModel> _userFromApiJson(Map<String, dynamic> json) async {
    final names = await _catalogLocationNames();
    return UserModel.fromApiJson(
      json,
      primaryLocation: names.primary,
      secondaryLocation: names.secondary,
    );
  }

  Future<UserModel> attachSuperadminFlag(UserModel user) async {
    try {
      final json = await _api.getJson('/api/auth/me');
      if (json is Map && json['is_superadmin'] == true) {
        return user.withSuperadmin(true);
      }
    } catch (_) {
      // Keep the cafe role only; the console stays hidden.
    }
    return user.withSuperadmin(false);
  }

  Future<({String primary, String secondary})> _catalogLocationNames() async {
    final locations = await _locations.getLocations();
    final primary = LocationCatalog.preferredName(locations);
    final secondary = LocationCatalog.otherName(locations, primary) ?? primary;
    return (primary: primary, secondary: secondary);
  }
}
