import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../scheduling_providers.dart';
import '../../domain/shift_model.dart';

class CoffeeCalendarWidget extends ConsumerStatefulWidget {
  final String location;
  const CoffeeCalendarWidget({Key? key, required this.location})
    : super(key: key);

  @override
  ConsumerState<CoffeeCalendarWidget> createState() =>
      _CoffeeCalendarWidgetState();
}

class _CoffeeCalendarWidgetState extends ConsumerState<CoffeeCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(shiftsForMonthProvider(widget.location));

    return shiftsAsync.when(
      data: (shifts) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: AppColors.borderLight.withValues(alpha: 0.6),
              width: 0.5,
            ),
            boxShadow: AppShadows.md,
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              ref.read(selectedDateProvider.notifier).state = selectedDay;
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
              leftChevronIcon: const Icon(
                Icons.chevron_left,
                color: AppColors.primaryPink,
              ),
              rightChevronIcon: const Icon(
                Icons.chevron_right,
                color: AppColors.primaryPink,
              ),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontSize: 12, color: AppColors.textLight),
              weekendStyle: TextStyle(
                fontSize: 12,
                color: AppColors.primaryPink,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildCell(day, shifts, false);
              },
              selectedBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryPink, width: 2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    boxShadow: AppShadows.coloredGlow(
                      AppColors.primaryPink,
                      intensity: 0.2,
                    ),
                  ),
                  child: _buildCell(day, shifts, true),
                );
              },
              todayBuilder: (context, day, focusedDay) {
                return Container(
                  margin: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accentPink, width: 2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: _buildCell(day, shifts, false),
                );
              },
            ),
          ),
        );
      },
      loading: () => const AppSkeleton(height: 280, borderRadius: AppSpacing.radiusXl),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildCell(DateTime day, List<ShiftModel> allShifts, bool isSelected) {
    final dayShifts = allShifts.where((s) => isSameDay(s.date, day)).toList();
    final totalHours = dayShifts.fold(0.0, (sum, s) => sum + s.durationInHours);
    final remainingHours = 22.0 - totalHours;
    final employeeCount = dayShifts.length;

    Color cellColor;
    Color textColor;

    if (remainingHours <= 0) {
      cellColor = Colors.redAccent.withValues(alpha: 0.15);
      textColor = Colors.red.shade700;
    } else if (remainingHours < 4) {
      cellColor = AppColors.softYellow.withValues(alpha: 0.6);
      textColor = Colors.orange.shade700;
    } else if (remainingHours < 8) {
      cellColor = AppColors.softGreen.withValues(alpha: 0.4);
      textColor = AppColors.textDark;
    } else {
      cellColor = AppColors.softGreen.withValues(alpha: 0.2);
      textColor = AppColors.textDark;
    }

    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isSelected ? AppColors.primaryPink : textColor,
              ),
            ),
            if (employeeCount > 0) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 10, color: textColor),
                  const SizedBox(width: 2),
                  Text(
                    '$employeeCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 2),
            Text(
              '${remainingHours.toStringAsFixed(0)}h',
              style: TextStyle(fontSize: 9, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
