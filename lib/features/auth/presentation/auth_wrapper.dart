import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_providers.dart';
import 'login_screen.dart';
import '../../admin/presentation/admin_dashboard.dart';
import '../../scheduling/presentation/employee_dashboard.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        
        final currentUser = ref.watch(currentUserProvider);
        return currentUser.when(
          data: (userModel) {
            if (userModel == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Profile not found in database.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(authRepositoryProvider).signOut(),
                        child: const Text('Sign Out & Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (userModel.isAdmin) {
              return const AdminDashboard();
            } else {
              return const EmployeeDashboard();
            }
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
