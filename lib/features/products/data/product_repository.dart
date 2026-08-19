import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/ttl_cache.dart';
import '../domain/product_model.dart';

class ProductRepository {
  ProductRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  final TtlCache<List<ProductModel>> _cache = TtlCache();

  Future<List<ProductModel>> getProducts() {
    return _cache.getOrLoad(_fetchProducts);
  }

  void invalidateCache() => _cache.invalidate();

  Future<List<ProductModel>> _fetchProducts() async {
    final json = await _api.getJson('/api/products');
    if (json is! List) {
      throw const ApiException('Expected a JSON array from /api/products');
    }
    return json
        .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
