import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/vacation_repository.dart';
import '../domain/vacation_model.dart';
import 'vacation_request_screen.dart';
import 'vacation_status_content.dart';

class VacationStatusScreen extends ConsumerWidget {
  const VacationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));

          return StreamBuilder<List<VacationModel>>(
            stream: ref
                .watch(vacationRepositoryProvider)
                .getVacationsForUser(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: AppLoadingIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              return VacationStatusContent(
                user: user,
                vacations: snapshot.data ?? const [],
                onRequestVacation: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VacationRequestScreen(),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Scaffold(body: AppLoadingIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
