import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/pwa/pwa_responsive.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/domain/user_model.dart';
import '../domain/vacation_model.dart';
import '../utils/vacation_balance_calculator.dart';
import '../utils/vacation_list_utils.dart';

enum VacationHistoryTab { approved, rejected }

/// Testable vacation history body used by [VacationStatusScreen].
class VacationStatusContent extends StatefulWidget {
  final UserModel user;
  final List<VacationModel> vacations;
  final VoidCallback onRequestVacation;

  const VacationStatusContent({
    super.key,
    required this.user,
    required this.vacations,
    required this.onRequestVacation,
  });

  @override
  State<VacationStatusContent> createState() => _VacationStatusContentState();
}

class _VacationStatusContentState extends State<VacationStatusContent> {
  VacationHistoryTab _selectedTab = VacationHistoryTab.approved;

  @override
  Widget build(BuildContext context) {
    final balance = VacationBalanceCalculator.calculate(
      employmentDate: widget.user.employmentDate,
      vacations: widget.vacations,
      asOf: DateTime.now(),
    );
    final pending = VacationListUtils.filterByStatus(
      widget.vacations,
      'pending',
    );
    final approved = VacationListUtils.filterByStatus(
      widget.vacations,
      'approved',
    );
    final rejected = VacationListUtils.filterByStatus(
      widget.vacations,
      'rejected',
    );
    final visibleRequests = _selectedTab == VacationHistoryTab.approved
        ? approved
        : rejected;

    return Column(
      children: [
        ScreenHeader(
          title: 'My Vacations',
          topPadding: PwaResponsive.topSafePadding(context) + AppSpacing.lg,
          onBack: () => Navigator.pop(context),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl + PwaResponsive.bottomSafePadding(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VacationBalanceCard(
                  balance: balance,
                  employmentDate: widget.user.employmentDate,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  text: 'Request Vacation',
                  onPressed: widget.onRequestVacation,
                  backgroundColor: AppColors.primaryPink,
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Pending approval',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...pending.map(
                    (vacation) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: VacationRequestCard(vacation: vacation),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                _VacationTabSelector(
                  selectedTab: _selectedTab,
                  approvedCount: approved.length,
                  rejectedCount: rejected.length,
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (visibleRequests.isEmpty)
                  _VacationTabEmptyState(tab: _selectedTab)
                else
                  ...visibleRequests.map(
                    (vacation) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: VacationRequestCard(vacation: vacation),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VacationBalanceCard extends StatelessWidget {
  final VacationBalanceResult balance;
  final DateTime? employmentDate;

  const _VacationBalanceCard({
    required this.balance,
    required this.employmentDate,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.brandTurquoise.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.beach_access_rounded,
                  color: AppColors.brandTurquoise,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Vacation Balance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!balance.hasEmploymentDate)
            const Text(
              'Your employment start date has not been configured yet. '
              'Please contact an administrator to set it before viewing your '
              'vacation balance.',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
                height: 1.4,
              ),
            )
          else ...[
            Text(
              '${balance.remainingDays} days remaining',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.brandGreen,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _BalanceMetric(
                    label: 'Used',
                    value: '${balance.usedDays}',
                    color: AppColors.brandMustard,
                  ),
                ),
                Expanded(
                  child: _BalanceMetric(
                    label: 'Earned',
                    value: '${balance.earnedDays}',
                    color: AppColors.brandTurquoise,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: balance.usageProgress,
                minHeight: 10,
                backgroundColor: AppColors.borderLight,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.brandGreen,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              employmentDate == null
                  ? 'Earned based on employment date'
                  : 'Earned based on employment date · '
                      '${DateFormat('dd MMM yyyy').format(employmentDate!)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BalanceMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _VacationTabSelector extends StatelessWidget {
  final VacationHistoryTab selectedTab;
  final int approvedCount;
  final int rejectedCount;
  final ValueChanged<VacationHistoryTab> onChanged;

  const _VacationTabSelector({
    required this.selectedTab,
    required this.approvedCount,
    required this.rejectedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.8),
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Approved',
              count: approvedCount,
              isSelected: selectedTab == VacationHistoryTab.approved,
              selectedColor: AppColors.brandGreen,
              onTap: () => onChanged(VacationHistoryTab.approved),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Rejected',
              count: rejectedCount,
              isSelected: selectedTab == VacationHistoryTab.rejected,
              selectedColor: AppColors.brandPurple,
              onTap: () => onChanged(VacationHistoryTab.rejected),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isSelected ? selectedColor : AppColors.textLight,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? selectedColor.withValues(alpha: 0.2)
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? selectedColor : AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VacationRequestCard extends StatelessWidget {
  final VacationModel vacation;

  const VacationRequestCard({
    super.key,
    required this.vacation,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(vacation.status);
    final rangeText =
        '${DateFormat('dd MMM').format(vacation.startDate)} → '
        '${DateFormat('dd MMM yyyy').format(vacation.endDate)}';

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  vacation.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Requested ${DateFormat('dd MMM yyyy').format(vacation.requestedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            rangeText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${vacation.durationInDays} Days',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.brandTurquoise,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateInfo(
                'From',
                DateFormat('dd MMM yyyy').format(vacation.startDate),
              ),
              _buildDateInfo(
                'To',
                DateFormat('dd MMM yyyy').format(vacation.endDate),
              ),
              _buildDateInfo(
                'Duration',
                '${vacation.durationInDays} Days',
              ),
            ],
          ),
          if (vacation.adminComment != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.brandGreen;
      case 'rejected':
        return Colors.red;
      default:
        return AppColors.brandMustard;
    }
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }
}

class _VacationTabEmptyState extends StatelessWidget {
  final VacationHistoryTab tab;

  const _VacationTabEmptyState({required this.tab});

  @override
  Widget build(BuildContext context) {
    final isApproved = tab == VacationHistoryTab.approved;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isApproved ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 42,
            color: AppColors.textLight.withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isApproved
                ? 'No approved vacation requests'
                : 'No rejected vacation requests',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
