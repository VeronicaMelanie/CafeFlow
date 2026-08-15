import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../data/product_repository.dart';
import '../domain/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(apiClient: ref.watch(apiClientProvider));
});

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(productRepositoryProvider).getProducts();
});
