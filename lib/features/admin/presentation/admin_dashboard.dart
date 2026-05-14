import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/constants/app_colors.dart';
import 'manage_schedule_screen.dart';
import 'vacation_approval_screen.dart';
import 'employee_management_screen.dart';
import 'consumption_log_screen.dart';
import 'distribution_screen.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context, ref),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildAdminCard(context, 'Manage\nSchedule', Icons.calendar_month_outlined, AppColors.softPink, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageScheduleScreen()));
                }),
                _buildAdminCard(context, 'Approve\nVacations', Icons.beach_access_outlined, AppColors.softYellow, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const VacationApprovalScreen()));
                }),
                _buildAdminCard(context, 'View\nEmployees', Icons.people_outline, AppColors.softGreen, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeManagementScreen()));
                }),
                _buildAdminCard(context, 'Consumption\nLogs', Icons.coffee_outlined, AppColors.softPurple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsumptionLogScreen()));
                }),
                _buildAdminCard(context, 'Distribute\nApp', Icons.qr_code_2_outlined, AppColors.softBlue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DistributionScreen()));
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 24, right: 24),
      decoration: const BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Admin Panel',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(
                'Managing CafeFlow System',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.textDark.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}
