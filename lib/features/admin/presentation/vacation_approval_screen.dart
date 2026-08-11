import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scheduling/data/vacation_repository.dart';
import '../../scheduling/domain/vacation_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';

class VacationApprovalScreen extends ConsumerWidget {
  const VacationApprovalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacationsAsync = ref.watch(pendingVacationsProvider);

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Vacation Requests',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: vacationsAsync.when(
                data: (vacations) {
                  if (vacations.isEmpty) return _buildEmptyState();

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    itemCount: vacations.length,
                    itemBuilder: (context, index) {
                      final vacation = vacations[index];
                      return _buildVacationCard(ref, vacation);
                    },
                  );
                },
                loading: () => const AppLoadingIndicator(),
                error: (e, st) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacationCard(WidgetRef ref, VacationModel vacation) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.softPink,
                child: Text(vacation.userName[0], style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vacation.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const Text('Pending Request', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo('From', DateFormat('dd MMM').format(vacation.startDate)),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.textLight),
              _buildDateInfo('To', DateFormat('dd MMM').format(vacation.endDate)),
              _buildDateInfo('Duration', '${vacation.durationInDays} Days'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildActionBtn('Reject', Colors.redAccent, () => _handleStatus(ref, vacation.id, 'rejected'))),
              const SizedBox(width: 16),
              Expanded(child: _buildActionBtn('Approve', Colors.green, () => _handleStatus(ref, vacation.id, 'approved'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No pending requests', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
        ],
      ),
    );
  }

  void _handleStatus(WidgetRef ref, String id, String status) {
    ref.read(vacationRepositoryProvider).updateVacationStatus(id, status);
  }
}

final pendingVacationsProvider = StreamProvider<List<VacationModel>>((ref) {
  return ref.watch(vacationRepositoryProvider).getAllPendingVacations();
});
