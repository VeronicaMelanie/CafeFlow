import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../data/location_repository.dart';
import '../domain/location_model.dart';
import '../utils/location_catalog.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(apiClient: ref.watch(apiClientProvider));
});

final locationsProvider = FutureProvider<List<LocationModel>>((ref) {
  return ref.watch(locationRepositoryProvider).getLocations();
});

List<String> watchLocationNames(WidgetRef ref) {
  return LocationCatalog.names(
    ref.watch(locationsProvider).valueOrNull ?? const [],
  );
}
