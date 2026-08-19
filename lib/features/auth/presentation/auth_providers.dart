import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/api/api_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../products/presentation/product_providers.dart';
import '../data/auth_repository.dart';
import '../data/users_repository.dart';
import '../domain/user_model.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(
    apiClient: ref.watch(apiClientProvider),
    locationRepository: ref.watch(locationRepositoryProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(usersRepository: ref.watch(usersRepositoryProvider));
});

final allUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getAllUsers();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  final model = await ref.read(authRepositoryProvider).getCurrentUserModel();
  if (model != null) {
    unawaited(ref.read(locationRepositoryProvider).getLocations());
    unawaited(ref.read(productRepositoryProvider).getProducts());
  }
  return model;
});

final allEmployeesProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getAllEmployees();
});
