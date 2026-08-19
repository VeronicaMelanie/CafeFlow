import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
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
    final l10n = L10n.of(context);

    return Column(
      children: [
        ScreenHeader(
          title: l10n.pick('My vacation', 'Concediile mele'),
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
                  text: l10n.pick('Request vacation', 'Cere concediu'),
                  onPressed: widget.onRequestVacation,
                  backgroundColor: AppColors.primaryPink,
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    l10n.pick('Pending approval', 'În așteptarea aprobării'),
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
    final l10n = L10n.of(context);
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
                l10n.pick('Vacation balance', 'Sold concediu'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!balance.hasEmploymentDate)
            Text(
              l10n.pick(
                'Your hire date is not set. Contact an administrator to see your vacation balance.',
                'Data de angajare nu a fost setată. '
                'Contactează un administrator ca să poți vedea '
                'soldul de concediu.',
              ),
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
                height: 1.4,
              ),
            )
          else ...[
            Text(
              l10n.pick(
                '${balance.remainingDays} days left',
                '${balance.remainingDays} zile rămase',
              ),
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
                    label: l10n.pick('Used', 'Folosite'),
                    value: '${balance.usedDays}',
                    color: AppColors.brandMustard,
                  ),
                ),
                Expanded(
                  child: _BalanceMetric(
                    label: l10n.pick('Accrued', 'Acumulate'),
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
                  ? l10n.pick(
                      'Accrued based on hire date',
                      'Acumulate pe baza datei de angajare',
                    )
                  : l10n.pick(
                      'Accrued based on hire date · ${DateFormat('dd MMM yyyy', l10n.isRo ? null : l10n.locale.languageCode).format(employmentDate!)}',
                      'Acumulate pe baza datei de angajare · ${DateFormat('dd MMM yyyy', l10n.isRo ? null : l10n.locale.languageCode).format(employmentDate!)}',
                    ),
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
              label: L10n.of(context).pick('Approved', 'Aprobat'),
              count: approvedCount,
              isSelected: selectedTab == VacationHistoryTab.approved,
              selectedColor: AppColors.brandGreen,
              onTap: () => onChanged(VacationHistoryTab.approved),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: L10n.of(context).pick('Rejected', 'Respins'),
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
    final l10n = L10n.of(context);
    final locale = l10n.isRo ? null : l10n.locale.languageCode;
    final statusColor = _statusColor(vacation.status);
    final rangeText =
        '${DateFormat('dd MMM', locale).format(vacation.startDate)} → '
        '${DateFormat('dd MMM yyyy', locale).format(vacation.endDate)}';
    final daysLabel = vacation.durationInDays == 1
        ? l10n.pick('1 day', '1 zi')
        : l10n.pick('${vacation.durationInDays} days', '${vacation.durationInDays} zile');

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
                  _statusLabel(vacation.status, l10n),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                l10n.pick(
                  'Requested ${DateFormat('dd MMM yyyy', locale).format(vacation.requestedAt)}',
                  'Cerere din ${DateFormat('dd MMM yyyy', locale).format(vacation.requestedAt)}',
                ),
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
            daysLabel,
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
                l10n.pick('From', 'De la'),
                DateFormat('dd MMM yyyy', locale).format(vacation.startDate),
              ),
              _buildDateInfo(
                l10n.pick('To', 'Până la'),
                DateFormat('dd MMM yyyy', locale).format(vacation.endDate),
              ),
              _buildDateInfo(
                l10n.pick('Duration', 'Durată'),
                daysLabel,
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

  static String _statusLabel(String status, L10n l10n) {
    switch (status) {
      case 'approved':
        return l10n.pick('Approved', 'Aprobat');
      case 'rejected':
        return l10n.pick('Rejected', 'Respins');
      case 'pending':
        return l10n.pick('Pending', 'În așteptare');
      default:
        return status;
    }
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
                ? L10n.of(context).pick(
                    'No approved vacation requests',
                    'Nu există cereri de concediu aprobate',
                  )
                : L10n.of(context).pick(
                    'No rejected vacation requests',
                    'Nu există cereri de concediu respinse',
                  ),
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
