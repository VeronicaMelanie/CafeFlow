import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../scheduling/data/vacation_repository.dart';
import '../../scheduling/domain/vacation_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';

class VacationApprovalScreen extends ConsumerWidget {
  const VacationApprovalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacationsAsync = ref.watch(pendingVacationsProvider);
    final l10n = L10n.of(context);

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Time-off requests', 'Cereri de concediu'),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: vacationsAsync.when(
                data: (vacations) {
                  if (vacations.isEmpty) return _buildEmptyState(context);

                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    itemCount: vacations.length,
                    itemBuilder: (context, index) {
                      final vacation = vacations[index];
                      return _buildVacationCard(context, ref, vacation);
                    },
                  );
                },
                loading: () => const AppLoadingIndicator(),
                error: (e, st) => Center(child: Text(l10n.errorWith(e))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacationCard(
    BuildContext context,
    WidgetRef ref,
    VacationModel vacation,
  ) {
    final l10n = L10n.of(context);
    final locale = l10n.isRo ? null : l10n.locale.languageCode;
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
                  Text(
                    l10n.pick('Pending request', 'Cerere în așteptare'),
                    style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo(
                l10n.pick('From', 'De la'),
                DateFormat('dd MMM', locale).format(vacation.startDate),
              ),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.textLight),
              _buildDateInfo(
                l10n.pick('Until', 'Până la'),
                DateFormat('dd MMM', locale).format(vacation.endDate),
              ),
              _buildDateInfo(
                l10n.pick('Duration', 'Durată'),
                l10n.pick(
                  '${vacation.durationInDays} days',
                  '${vacation.durationInDays} zile',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  l10n.pick('Reject', 'Respinge'),
                  Colors.redAccent,
                  () => _handleStatus(context, ref, vacation, 'rejected'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionBtn(
                  l10n.pick('Approve', 'Aprobă'),
                  Colors.green,
                  () => _handleStatus(context, ref, vacation, 'approved'),
                ),
              ),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            L10n.of(context).pick(
              'No pending requests',
              'Nicio cerere în așteptare',
            ),
            style: const TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatus(
    BuildContext context,
    WidgetRef ref,
    VacationModel vacation,
    String status,
  ) async {
    try {
      await ref
          .read(vacationRepositoryProvider)
          .updateVacationStatus(vacation, status);
      ref.invalidate(pendingVacationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).errorWith(e)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

final pendingVacationsProvider = StreamProvider<List<VacationModel>>((ref) {
  return ref.watch(vacationRepositoryProvider).getAllPendingVacations();
});
