import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/services/fcm_service.dart';
import 'auth_providers.dart';
import 'login_screen.dart';
import 'contract_type_onboarding.dart';
import '../../admin/presentation/admin_dashboard.dart';
import '../../scheduling/presentation/employee_main_shell.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  String? _fcmSyncedForUid;
  bool _contractSheetShown = false;

  @override
  Widget build(BuildContext context) {
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

            if (userModel.needsContractType && !_contractSheetShown) {
              _contractSheetShown = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final selected = await showContractTypeOnboarding(
                  context: context,
                  userName: userModel.name.isNotEmpty ? userModel.name : 'Employee',
                );
                if (selected == null) {
                  _contractSheetShown = false;
                  return;
                }
                await ref.read(authRepositoryProvider).setContractType(
                      uid: userModel.uid,
                      contractType: selected,
                    );
                ref.invalidate(currentUserProvider);
              });
            }

            if (_fcmSyncedForUid != userModel.uid) {
              _fcmSyncedForUid = userModel.uid;
              FcmService.syncTokenForUser(userModel.uid);
            }

            if (userModel.isAdmin) {
              return const AdminDashboard();
            } else {
              return const EmployeeMainShell();
            }
          },
          loading: () => const Scaffold(body: AppLoadingIndicator()),
          error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
        );
      },
      loading: () => const Scaffold(body: AppLoadingIndicator()),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}
