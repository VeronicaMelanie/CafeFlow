import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/location_model.dart';

class LocationRepository {
  LocationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<LocationModel>> getLocations() async {
    final json = await _api.getJson('/api/locations');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/locations');
    }
    return json
        .map((item) => LocationModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
