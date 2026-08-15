import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/product_model.dart';

class ProductRepository {
  ProductRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<List<ProductModel>> getProducts() async {
    final json = await _api.getJson('/api/products');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/products');
    }
    return json
        .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
