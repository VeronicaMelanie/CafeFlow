import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../products/presentation/product_providers.dart';
import 'superadmin_repository.dart';

final superadminRepositoryProvider = Provider<SuperadminRepository>((ref) {
  return SuperadminRepository(
    apiClient: ref.watch(apiClientProvider),
    usersRepository: ref.watch(usersRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

final superadminOverviewProvider =
    FutureProvider<SuperadminOverview>((ref) {
  return ref.watch(superadminRepositoryProvider).getOverview();
});
