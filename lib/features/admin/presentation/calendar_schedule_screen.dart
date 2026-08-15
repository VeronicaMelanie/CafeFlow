import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../scheduling/domain/shift_model.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../../locations/presentation/location_providers.dart';

class CalendarScheduleScreen extends ConsumerStatefulWidget {
  const CalendarScheduleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CalendarScheduleScreen> createState() =>
      _CalendarScheduleScreenState();
}

class _CalendarScheduleScreenState
    extends ConsumerState<CalendarScheduleScreen> {
  String _selectedLocation = 'Gara';
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Current Schedule',
              onBack: () => Navigator.pop(context),
            ),
            _buildLocationSelector(),
            _buildMonthSelector(),
            Expanded(child: _buildCalendarGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector() {
    final names = watchLocationNames(ref);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.6),
            width: 0.5,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            for (final name in names) _buildLocationItem(name),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationItem(String location) {
    final isSelected = _selectedLocation == location;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedLocation = location);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pureWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill - 3),
            border: isSelected
                ? Border.all(
                    color: AppColors.brandGreen.withValues(alpha: 0.3),
                    width: 0.5,
                  )
                : null,
            boxShadow: isSelected ? AppShadows.xs : null,
          ),
          child: Center(
            child: Text(
              location,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? AppColors.brandGreen : AppColors.textLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              setState(
                () => _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                  1,
                ),
              );
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_selectedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(
                () => _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                  1,
                ),
              );
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return StreamBuilder<List<ShiftModel>>(
      stream: ref
          .read(shiftRepositoryProvider)
          .getShiftsForMonth(_selectedMonth, _selectedLocation),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const AppLoadingIndicator();
        }

        final shifts = snapshot.data!;
        return _buildCalendar(shifts);
      },
    );
  }

  Widget _buildCalendar(List<ShiftModel> shifts) {
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final firstDayOfWeek = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
      1,
    ).weekday;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          _buildWeekdayHeader(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.8,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: firstDayOfWeek - 1 + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstDayOfWeek - 1) {
                  return const SizedBox.shrink();
                }

                final day = index - (firstDayOfWeek - 1) + 1;
                final date = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month,
                  day,
                );
                final dayShifts = shifts
                    .where(
                      (s) =>
                          s.date.day == day &&
                          s.date.month == _selectedMonth.month,
                    )
                    .toList();

                return _buildDayCell(date, dayShifts);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayCell(DateTime date, List<ShiftModel> shifts) {
    final isUnderstaffed = shifts.length < 2;
    final cellColor = isUnderstaffed && shifts.isNotEmpty
        ? AppColors.brandRed.withValues(alpha: 0.15)
        : AppColors.pureWhite;

    return Container(
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUnderstaffed && shifts.isNotEmpty
              ? AppColors.brandRed.withValues(alpha: 0.5)
              : AppColors.borderLight.withValues(alpha: 0.6),
          width: isUnderstaffed && shifts.isNotEmpty ? 1.0 : 0.5,
        ),
        boxShadow: AppShadows.xs,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isUnderstaffed && shifts.isNotEmpty
                    ? AppColors.brandRed
                    : AppColors.textDark,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: shifts.take(2).map((shift) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        shift.userName.split(' ').first,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
