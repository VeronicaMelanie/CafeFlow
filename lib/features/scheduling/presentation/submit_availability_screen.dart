import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/availability_model.dart';

class SubmitAvailabilityScreen extends ConsumerStatefulWidget {
  const SubmitAvailabilityScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubmitAvailabilityScreen> createState() => _SubmitAvailabilityScreenState();
}

class _SubmitAvailabilityScreenState extends ConsumerState<SubmitAvailabilityScreen> {
  DateTime _focusedDay = DateTime.now();
  final Set<DateTime> _availableDays = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentAvailability();
  }

  Future<void> _loadCurrentAvailability() async {
    setState(() => _isLoading = true);
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final snap = await FirebaseFirestore.instance
          .collection('availability')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      setState(() {
        for (var doc in snap.docs) {
          final date = (doc.data()['date'] as Timestamp).toDate();
          _availableDays.add(DateTime(date.year, date.month, date.day));
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDay(DateTime day) async {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    
    if (_availableDays.contains(normalizedDay)) {
      final snap = await FirebaseFirestore.instance
          .collection('availability')
          .where('userId', isEqualTo: user.uid)
          .where('date', isEqualTo: Timestamp.fromDate(normalizedDay))
          .get();
      for (var doc in snap.docs) {
        await doc.reference.delete();
      }
      _availableDays.remove(normalizedDay);
    } else {
      await FirebaseFirestore.instance.collection('availability').add(
        AvailabilityModel(
          id: '',
          userId: user.uid,
          date: normalizedDay,
          isFullDay: true,
        ).toMap(),
      );
      _availableDays.add(normalizedDay);
    }
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 32),
                      _buildCalendarCard(),
                      const SizedBox(height: 40),
                      _buildPrimaryCTA(context),
                    ],
                  ),
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
            'Availability',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.softPink.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primaryPink),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Tap on the days you are available to work. Selected days will be used for automatic scheduling.',
              style: TextStyle(color: AppColors.textDark.withOpacity(0.8), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.now(),
        lastDay: DateTime.now().add(const Duration(days: 90)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => _availableDays.contains(DateTime(day.year, day.month, day.day)),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() => _focusedDay = focusedDay);
          _toggleDay(selectedDay);
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primaryPink),
          rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primaryPink),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(color: AppColors.primaryPink, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: AppColors.primaryPink.withOpacity(0.2), shape: BoxShape.circle),
          todayTextStyle: const TextStyle(color: AppColors.primaryPink, fontWeight: FontWeight.bold),
          weekendTextStyle: const TextStyle(color: AppColors.accentPink),
        ),
      ),
    );
  }

  Widget _buildPrimaryCTA(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: AppColors.pinkGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: AppColors.primaryPink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Text('Save & Done', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
