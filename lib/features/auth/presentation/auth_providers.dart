import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  return ref.read(authRepositoryProvider).getCurrentUserModel();
});

final allEmployeesProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).getAllEmployees();
});
