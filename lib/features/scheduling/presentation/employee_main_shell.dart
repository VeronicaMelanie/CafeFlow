import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/employee_bottom_nav_bar.dart';
import 'employee_dashboard.dart';
import 'profile_screen.dart';
import 'scheduling_providers.dart';
import 'stats_screen.dart';
import 'team_screen.dart';

/// Persistent shell for the four main employee sections with shared bottom nav.
class EmployeeMainShell extends ConsumerWidget {
  const EmployeeMainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(employeeMainTabProvider);

    return Scaffold(
      backgroundColor: AppColors.creamBackground,
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex,
            children: const [
              EmployeeDashboard(),
              TeamScreen(),
              StatsScreen(),
              ProfileScreen(),
            ],
          ),
          EmployeeBottomNavBar(
            selectedIndex: selectedIndex,
            onTabSelected: (index) {
              ref.read(employeeMainTabProvider.notifier).state = index;
            },
          ),
        ],
      ),
    );
  }
}
