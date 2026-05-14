import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scheduling/data/vacation_repository.dart';
import '../../scheduling/domain/vacation_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class VacationApprovalScreen extends ConsumerWidget {
  const VacationApprovalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacationsAsync = ref.watch(pendingVacationsProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: vacationsAsync.when(
              data: (vacations) {
                if (vacations.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: vacations.length,
                  itemBuilder: (context, index) {
                    final vacation = vacations[index];
                    return _buildVacationCard(ref, vacation);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 24),
      decoration: const BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'Vacation Requests',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVacationCard(WidgetRef ref, VacationModel vacation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.softPink,
                child: Text(vacation.userName[0], style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(vacation.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildActionBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access_outlined, size: 64, color: AppColors.textLight.withOpacity(0.3)),
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
