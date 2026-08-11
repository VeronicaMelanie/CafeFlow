import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../consumption/data/consumption_repository.dart';
import '../../consumption/domain/consumption_model.dart';
import '../../scheduling/domain/shift_model.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../../auth/domain/user_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';

class ConsumptionLogScreen extends ConsumerWidget {
  const ConsumptionLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(allEmployeesProvider);

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Employee Consumption',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: employeesAsync.when(
                data: (employees) {
                  if (employees.isEmpty) return _buildEmptyState();

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      _buildSectionHeader(
                        'Employees',
                        '${employees.length} total',
                      ),
                      const SizedBox(height: 12),
                      ...employees.map(
                        (employee) =>
                            _buildEmployeeCard(context, ref, employee),
                      ),
                    ],
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

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(
    BuildContext context,
    WidgetRef ref,
    UserModel employee,
  ) {
    final now = DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.6),
          width: 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EmployeeConsumptionDetailScreen(employee: employee),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.brandGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StreamBuilder<List<ConsumptionModel>>(
                    stream: ref
                        .read(consumptionRepositoryProvider)
                        .getUserConsumptions(employee.uid, now),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text(
                          'Error loading',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Text(
                          'Loading...',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                        );
                      }
                      final consumptions = snapshot.data!;
                      final totalQty = consumptions.fold(
                        0,
                        (sum, c) => sum + c.quantity,
                      );
                      return Text(
                        '$totalQty items this month',
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No employees found',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class EmployeeConsumptionDetailScreen extends ConsumerStatefulWidget {
  final UserModel employee;

  const EmployeeConsumptionDetailScreen({Key? key, required this.employee})
    : super(key: key);

  @override
  ConsumerState<EmployeeConsumptionDetailScreen> createState() =>
      _EmployeeConsumptionDetailScreenState();
}

class _EmployeeConsumptionDetailScreenState
    extends ConsumerState<EmployeeConsumptionDetailScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: widget.employee.name,
            onBack: () => Navigator.pop(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: _buildMonthSelector(),
          ),
          Expanded(
            child: StreamBuilder<List<ShiftModel>>(
              stream: ref
                  .read(shiftRepositoryProvider)
                  .getUserShiftsForMonth(widget.employee.uid, _selectedMonth),
              builder: (context, shiftsSnapshot) {
                if (shiftsSnapshot.hasError) {
                  return Center(child: Text('Error: ${shiftsSnapshot.error}'));
                }
                if (!shiftsSnapshot.hasData) {
                  return const AppLoadingIndicator();
                }
                final shifts = shiftsSnapshot.data!;

                return StreamBuilder<List<ConsumptionModel>>(
                  stream: ref
                      .read(consumptionRepositoryProvider)
                      .getUserConsumptions(widget.employee.uid, _selectedMonth),
                  builder: (context, consumptionsSnapshot) {
                    if (consumptionsSnapshot.hasError) {
                      return Center(
                        child: Text('Error: ${consumptionsSnapshot.error}'),
                      );
                    }
                    if (!consumptionsSnapshot.hasData) {
                      return const AppLoadingIndicator();
                    }
                    final consumptions = consumptionsSnapshot.data!;
                    return _buildDayList(shifts, consumptions);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month - 1,
                1,
              );
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _selectedMonth = DateTime(
                _selectedMonth.year,
                _selectedMonth.month + 1,
                1,
              );
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildDayList(
    List<ShiftModel> shifts,
    List<ConsumptionModel> consumptions,
  ) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final List<DayData> days = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final dayShifts = shifts
          .where(
            (s) => s.date.day == day && s.date.month == _selectedMonth.month,
          )
          .toList();
      final dayConsumptions = consumptions
          .where(
            (c) => c.date.day == day && c.date.month == _selectedMonth.month,
          )
          .toList();

      days.add(
        DayData(date: date, shifts: dayShifts, consumptions: dayConsumptions),
      );
    }

    if (days.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: days.length,
      itemBuilder: (context, index) {
        return _buildDayCard(days[index]);
      },
    );
  }

  Widget _buildDayCard(DayData dayData) {
    final hasShift = dayData.shifts.isNotEmpty;
    final hasConsumption = dayData.consumptions.isNotEmpty;
    final isIrregular = hasConsumption && !hasShift;

    Color cardColor = AppColors.pureWhite;
    if (isIrregular) {
      cardColor = AppColors.brandRed.withValues(alpha: 0.1);
    } else if (hasShift) {
      cardColor = AppColors.brandGreen.withValues(alpha: 0.05);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isIrregular
              ? AppColors.brandRed.withValues(alpha: 0.5)
              : AppColors.borderLight.withValues(alpha: 0.6),
          width: isIrregular ? 1.0 : 0.5,
        ),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, dd MMM').format(dayData.date),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIrregular ? AppColors.brandRed : AppColors.textDark,
                ),
              ),
              if (isIrregular)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Irregular',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandRed,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasShift) ...[
            _buildShiftInfo(dayData.shifts.first),
            const SizedBox(height: 8),
          ] else if (!hasConsumption) ...[
            Text(
              'No shift',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (hasConsumption) ...[
            const Text(
              'Consumption:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 4),
            ...dayData.consumptions.map((c) => _buildConsumptionItem(c)),
          ],
        ],
      ),
    );
  }

  Widget _buildShiftInfo(ShiftModel shift) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(
            Icons.work_outline,
            size: 16,
            color: AppColors.brandGreen,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          shift.location,
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
      ],
    );
  }

  Widget _buildConsumptionItem(ConsumptionModel consumption) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryPink.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.coffee_outlined,
              size: 14,
              color: AppColors.primaryPink,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              consumption.productName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            'x${consumption.quantity}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryPink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.textLight.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No data for this month',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class DayData {
  final DateTime date;
  final List<ShiftModel> shifts;
  final List<ConsumptionModel> consumptions;

  DayData({
    required this.date,
    required this.shifts,
    required this.consumptions,
  });
}
