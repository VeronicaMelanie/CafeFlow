import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/vacation_repository.dart';
import '../domain/vacation_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import 'vacation_request_screen.dart';

class VacationStatusScreen extends ConsumerWidget {
  const VacationStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));

          return Column(
            children: [
              ScreenHeader(
                title: 'My Vacations',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: StreamBuilder<List<VacationModel>>(
                  stream: ref
                      .watch(vacationRepositoryProvider)
                      .getVacationsForUser(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AppLoadingIndicator();
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final vacations = snapshot.data ?? [];

                    if (vacations.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      itemCount: vacations.length,
                      itemBuilder: (context, index) {
                        final vacation = vacations[index];
                        return _buildVacationCard(vacation);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Scaffold(body: AppLoadingIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VacationRequestScreen()),
          );
        },
        backgroundColor: AppColors.primaryPink,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Request Vacation',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildVacationCard(VacationModel vacation) {
    Color statusColor;
    IconData statusIcon;

    switch (vacation.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vacation.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy').format(vacation.requestedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo(
                'From',
                DateFormat('dd MMM yyyy').format(vacation.startDate),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 16,
                color: AppColors.textLight,
              ),
              _buildDateInfo(
                'To',
                DateFormat('dd MMM yyyy').format(vacation.endDate),
              ),
              _buildDateInfo('Duration', '${vacation.durationInDays} Days'),
            ],
          ),
          if (vacation.adminComment != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      vacation.adminComment!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textLight),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.beach_access_outlined,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'No vacation requests yet',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Tap + to request a vacation',
            style: TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
