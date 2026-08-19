import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../auth/data/users_repository.dart';
import '../../auth/domain/user_model.dart';
import '../../locations/data/location_repository.dart';
import '../../locations/domain/location_model.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product_model.dart';

class SuperadminOverview {
  const SuperadminOverview({
    required this.users,
    required this.products,
    required this.locations,
    required this.shifts,
    required this.availability,
    required this.vacations,
    required this.consumptions,
  });

  final int users;
  final int products;
  final int locations;
  final int shifts;
  final int availability;
  final int vacations;
  final int consumptions;

  factory SuperadminOverview.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return SuperadminOverview(
      users: n('users'),
      products: n('products'),
      locations: n('locations'),
      shifts: n('shifts'),
      availability: n('availability'),
      vacations: n('vacations'),
      consumptions: n('consumptions'),
    );
  }
}

class SuperadminRepository {
  SuperadminRepository({
    required ApiClient apiClient,
    required UsersRepository usersRepository,
    required ProductRepository productRepository,
    required LocationRepository locationRepository,
  })  : _api = apiClient,
        _users = usersRepository,
        _products = productRepository,
        _locations = locationRepository;

  final ApiClient _api;
  final UsersRepository _users;
  final ProductRepository _products;
  final LocationRepository _locations;

  Future<SuperadminOverview> getOverview() async {
    final json = await _api.getJson('/api/superadmin/overview');
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from /api/superadmin/overview');
    }
    return SuperadminOverview.fromJson(Map<String, dynamic>.from(json));
  }

  Future<UserModel> patchUser({
    required String postgresId,
    String? name,
    String? role,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (role != null) body['role'] = role;
    final json = await _api.patchJson(
      '/api/superadmin/users/$postgresId',
      body: body,
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from PATCH user');
    }
    _users.invalidateCache();
    final firebaseUid = json['firebase_uid']?.toString() ?? '';
    final fromList = await _users.findByFirebaseUid(firebaseUid);
    if (fromList != null) return fromList;
    return UserModel.fromApiJson(
      Map<String, dynamic>.from(json),
      primaryLocation: 'Gara',
      secondaryLocation: 'Avantgarden',
    );
  }

  Future<void> deleteUser(String postgresId) async {
    await _api.delete('/api/superadmin/users/$postgresId');
    _users.invalidateCache();
  }

  Future<ProductModel> createProduct({required String name}) async {
    final json = await _api.postJson(
      '/api/superadmin/products',
      body: {'name': name},
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from POST product');
    }
    _products.invalidateCache();
    return ProductModel.fromJson(Map<String, dynamic>.from(json));
  }

  Future<ProductModel> patchProduct({
    required String id,
    String? name,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (isActive != null) body['is_active'] = isActive;
    final json = await _api.patchJson(
      '/api/superadmin/products/$id',
      body: body,
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from PATCH product');
    }
    _products.invalidateCache();
    return ProductModel.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> deleteProduct(String id) async {
    await _api.delete('/api/superadmin/products/$id');
    _products.invalidateCache();
  }

  Future<LocationModel> createLocation({required String name}) async {
    final json = await _api.postJson(
      '/api/superadmin/locations',
      body: {'name': name},
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from POST location');
    }
    _locations.invalidateCache();
    return LocationModel.fromJson(Map<String, dynamic>.from(json));
  }

  Future<LocationModel> patchLocation({
    required String id,
    String? name,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (isActive != null) body['is_active'] = isActive;
    final json = await _api.patchJson(
      '/api/superadmin/locations/$id',
      body: body,
    );
    if (json is! Map) {
      throw const ApiException('Expected a JSON object from PATCH location');
    }
    _locations.invalidateCache();
    return LocationModel.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> deleteVacation(String id) async {
    await _api.delete('/api/superadmin/vacations/$id');
  }
}
