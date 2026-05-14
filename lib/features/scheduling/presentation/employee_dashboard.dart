import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/auth_providers.dart';
import 'widgets/coffee_calendar_widget.dart';
import 'scheduling_providers.dart';
import '../../consumption/presentation/consumption_entry_screen.dart';
import 'submit_availability_screen.dart';
import '../domain/shift_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/notification_service.dart';

class EmployeeDashboard extends ConsumerStatefulWidget {
  const EmployeeDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends ConsumerState<EmployeeDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _scheduleReminders();
  }

  Future<void> _scheduleReminders() async {
    await Future.delayed(const Duration(seconds: 2));
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      final shifts = await ref.read(shiftRepositoryProvider).getEmployeeShifts(user.uid);
      final notificationService = NotificationService();
      await notificationService.cancelAllNotifications();
      for (int i = 0; i < shifts.length; i++) {
        final shift = shifts[i];
        if (shift.status == 'approved') {
          final reminderTime = shift.startTime.subtract(const Duration(days: 1));
          if (reminderTime.isAfter(DateTime.now())) {
            await notificationService.scheduleShiftReminder(
              id: i,
              title: 'Shift Tomorrow!',
              body: 'Reminder: You have a shift tomorrow at ${shift.location} from ${DateFormat('HH:mm').format(shift.startTime)} to ${DateFormat('HH:mm').format(shift.endTime)}.',
              scheduledDate: reminderTime,
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(selectedLocationProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not logged in'));
          final statsAsync = ref.watch(employeeStatsProvider(user.uid));

          return Stack(
            children: [
              Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildLocationSwitcher(location),
                          const SizedBox(height: 24),
                          _buildStatsSection(statsAsync),
                          const SizedBox(height: 32),
                          _buildUpcomingShiftsSection(user.uid),
                          const SizedBox(height: 32),
                          _buildActionCards(context),
                          const SizedBox(height: 32),
                          _buildPrimaryCTA(context, location, user),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildBottomNavBar(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
          const Text(
            'My Schedule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSwitcher(String location) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildLocationItem('Gara', location == 'Gara'),
          _buildLocationItem('Avantgarden', location == 'Avantgarden'),
        ],
      ),
    );
  }

  Widget _buildLocationItem(String label, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(selectedLocationProvider.notifier).state = label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.pureWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(21),
            border: isSelected ? Border.all(color: AppColors.primaryPink.withOpacity(0.3)) : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryPink.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 18,
                  color: isSelected ? AppColors.primaryPink : AppColors.textLight,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primaryPink : AppColors.textLight,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle, size: 14, color: AppColors.primaryPink),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<EmployeeStats> statsAsync) {
    return statsAsync.when(
      data: (stats) {
        final now = DateTime.now();
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final daysLeft = lastDay - now.day;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildStatCard('This Month', '$daysLeft', 'Days left', AppColors.softPink, Icons.calendar_today),
              const SizedBox(width: 12),
              _buildStatCard('Target Hours', '${stats.targetHours}h', 'Monthly goal', AppColors.softYellow, Icons.access_time),
              const SizedBox(width: 12),
              _buildStatCard('Completed', '${stats.totalHours.toInt()}h', 'This month', AppColors.softGreen, Icons.check_circle_outline),
              const SizedBox(width: 12),
              _buildStatCard('Remaining', '${(stats.targetHours - stats.totalHours).clamp(0, stats.targetHours).toInt()}h', 'To reach goal', AppColors.softPurple, Icons.hourglass_empty),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => const Text('Error loading stats'),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: AppColors.textDark.withOpacity(0.7)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildUpcomingShiftsSection(String userId) {
    final now = DateTime.now();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Upcoming Shifts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () {},
              icon: const Text('View full calendar', style: TextStyle(color: AppColors.primaryPink, fontSize: 13)),
              label: const Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryPink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: StreamBuilder<List<ShiftModel>>(
            stream: ref.read(shiftRepositoryProvider).getUserShiftsForMonth(userId, now),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final shifts = snapshot.data!;
              
              // Get next 7 days
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = now.add(Duration(days: index));
                  final dayShifts = shifts.where((s) => s.date.day == date.day && s.date.month == date.month).toList();
                  
                  return _buildShiftCard(date, dayShifts.isNotEmpty ? dayShifts.first : null);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShiftCard(DateTime date, ShiftModel? shift) {
    final isToday = date.day == DateTime.now().day;
    final colors = [AppColors.softPink, AppColors.softYellow, AppColors.softGreen, AppColors.softPurple, AppColors.softBlue];
    final color = shift != null ? colors[date.day % colors.length] : AppColors.pureWhite;

    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isToday ? AppColors.primaryPink : AppColors.borderLight),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(DateFormat('EEE').format(date), style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold)),
          Text('${date.day}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (shift != null) ...[
            Text('${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}', 
                 style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            Text(shift.location, style: const TextStyle(fontSize: 10, color: AppColors.textLight)),
          ] else ...[
            const Text('—', style: TextStyle(color: AppColors.textLight)),
            const Text('No shift', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildSmallActionCard('Consumption', 'Add or view your\nconsumptions', Icons.coffee_outlined, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ConsumptionEntryScreen()));
        })),
        const SizedBox(width: 16),
        Expanded(child: _buildSmallActionCard('Availability', 'Manage your\navailable days', Icons.calendar_month_outlined, () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const SubmitAvailabilityScreen()));
        })),
      ],
    );
  }

  Widget _buildSmallActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.softPink.withOpacity(0.5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: AppColors.pureWhite, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primaryPink),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryCTA(BuildContext context, String location, dynamic user) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPink.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _showBookingModal(context, ref, location, user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.white),
            SizedBox(width: 8),
            Text('Book Shift', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(color: AppColors.shadowColor, blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(0, Icons.calendar_today_outlined, 'My Schedule'),
            _buildNavItem(1, Icons.people_outline, 'Team'),
            _buildNavItem(2, Icons.bar_chart_outlined, 'Stats'),
            _buildNavItem(3, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected ? BoxDecoration(
          color: AppColors.softPink.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ) : null,
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryPink : AppColors.textLight),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold, fontSize: 12)),
            ]
          ],
        ),
      ),
    );
  }

  void _showBookingModal(BuildContext context, WidgetRef ref, String location, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BookingModal(location: location, user: user);
      }
    );
  }
}

class _BookingModal extends ConsumerStatefulWidget {
  final String location;
  final dynamic user;
  const _BookingModal({required this.location, required this.user});

  @override
  ConsumerState<_BookingModal> createState() => _BookingModalState();
}

class _BookingModalState extends ConsumerState<_BookingModal> {
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isCustom = false;

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text('Book Shift at ${widget.location}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Date: ${DateFormat('dd MMMM yyyy').format(selectedDate)}', style: const TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 24),
          _buildOption(
            title: 'Full Shift (07:00 - 18:00)',
            subtitle: '11 hours total',
            isSelected: !_isCustom,
            onTap: () => setState(() => _isCustom = false),
          ),
          const SizedBox(height: 12),
          _buildOption(
            title: 'Custom Hours',
            subtitle: _isCustom ? '${_startTime.format(context)} - ${_endTime.format(context)}' : 'Select specific interval',
            isSelected: _isCustom,
            onTap: () => setState(() => _isCustom = true),
          ),
          if (_isCustom) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(context: context, initialTime: _startTime);
                    if (time != null) setState(() => _startTime = time);
                  },
                  child: Text('Start: ${_startTime.format(context)}'),
                )),
                const SizedBox(width: 16),
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(context: context, initialTime: _endTime);
                    if (time != null) setState(() => _endTime = time);
                  },
                  child: Text('End: ${_endTime.format(context)}'),
                )),
              ],
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _confirmBooking(context, selectedDate),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Confirm Booking', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption({required String title, required String subtitle, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? AppColors.primaryPink : AppColors.borderLight, width: 2),
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? AppColors.softPink.withOpacity(0.3) : null,
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? AppColors.primaryPink : AppColors.textLight),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBooking(BuildContext context, DateTime date) async {
    final startDateTime = DateTime(date.year, date.month, date.day, _startTime.hour, _startTime.minute);
    final endDateTime = DateTime(date.year, date.month, date.day, _endTime.hour, _endTime.minute);

    final shift = ShiftModel(
      id: '',
      userId: widget.user.uid,
      userName: widget.user.name,
      date: date,
      startTime: startDateTime,
      endTime: endDateTime,
      type: _isCustom ? 'CUSTOM' : 'FULL',
      location: widget.location,
      status: 'pending',
    );

    final error = await ref.read(shiftRepositoryProvider).bookShift(shift);
    if (context.mounted) {
      if (error == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift booked successfully!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }
}
