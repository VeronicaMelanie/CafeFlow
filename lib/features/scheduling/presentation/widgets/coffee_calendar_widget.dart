import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../scheduling_providers.dart';
import '../../domain/shift_model.dart';

class CoffeeCalendarWidget extends ConsumerStatefulWidget {
  final String location;
  const CoffeeCalendarWidget({Key? key, required this.location}) : super(key: key);

  @override
  ConsumerState<CoffeeCalendarWidget> createState() => _CoffeeCalendarWidgetState();
}

class _CoffeeCalendarWidgetState extends ConsumerState<CoffeeCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

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
        return TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            ref.read(selectedDateProvider.notifier).state = selectedDay;
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              return _buildCell(day, shifts);
            },
            selectedBuilder: (context, day, focusedDay) {
              return Container(
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryPink, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),

                child: _buildCell(day, shifts),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildCell(DateTime day, List<ShiftModel> allShifts) {
    final dayShifts = allShifts.where((s) => isSameDay(s.date, day)).toList();
    final totalHours = dayShifts.fold(0.0, (sum, s) => sum + s.durationInHours);
    final remainingHours = 22.0 - totalHours;

    Color cellColor = Colors.white;
    if (remainingHours <= 0) {
      cellColor = Colors.redAccent.withOpacity(0.2);
    } else if (remainingHours < 4) {
      cellColor = AppColors.softYellow.withOpacity(0.5);
    } else {
      cellColor = AppColors.softGreen.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: cellColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${remainingHours.toInt()}h left', style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
