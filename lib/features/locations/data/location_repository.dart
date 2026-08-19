import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/ttl_cache.dart';
import '../domain/location_model.dart';

class LocationRepository {
  LocationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  final TtlCache<List<LocationModel>> _cache = TtlCache();

  Future<List<LocationModel>> getLocations() {
    return _cache.getOrLoad(_fetchLocations);
  }

  void invalidateCache() => _cache.invalidate();

  Future<List<LocationModel>> _fetchLocations() async {
    final json = await _api.getJson('/api/locations');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/locations');
    }
    return json
        .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
