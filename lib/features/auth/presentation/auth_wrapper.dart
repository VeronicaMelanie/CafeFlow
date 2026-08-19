import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/services/fcm_service.dart';
import 'auth_providers.dart';
import 'login_screen.dart';
import 'contract_type_onboarding.dart';
import '../../admin/presentation/admin_dashboard.dart';
import '../../scheduling/data/scheduling_window_automation.dart';
import '../../scheduling/presentation/employee_main_shell.dart';
import '../../superadmin/presentation/superadmin_dashboard.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  String? _fcmSyncedForUid;
  String? _windowAutomationForUid;

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
              final l10n = L10n.of(context);
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.pick(
                          'Profile was not found in the database.',
                          'Profilul nu a fost găsit în baza de date.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        child: Text(
                          l10n.pick(
                            'Sign out and try again',
                            'Deconectare și încearcă din nou',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (userModel.needsContractType) {
              return ContractTypeOnboardingScreen(user: userModel);
            }

            if (_fcmSyncedForUid != userModel.uid) {
              _fcmSyncedForUid = userModel.uid;
              FcmService.syncTokenForUser(userModel.uid);
            }
            if (_windowAutomationForUid != userModel.uid) {
              _windowAutomationForUid = userModel.uid;
              unawaited(SchedulingWindowAutomation.maybeRun(ref));
            }

            if (userModel.isSuperadmin) {
              return const SuperadminDashboard();
            }
            if (userModel.isAdmin) {
              return const AdminDashboard();
            }
            return const EmployeeMainShell();
          },
          loading: () => const Scaffold(body: AppLoadingIndicator()),
          error: (e, st) => Scaffold(
            body: Center(child: Text(L10n.of(context).errorWith(e))),
          ),
        );
      },
      loading: () => const Scaffold(body: AppLoadingIndicator()),
      error: (e, st) => Scaffold(
        body: Center(child: Text(L10n.of(context).errorWith(e))),
      ),
    );
  }
}
