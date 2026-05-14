import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../scheduling/data/scheduling_service.dart';
import '../../scheduling/domain/shift_model.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  const ManageScheduleScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> {
  final SchedulingService _schedulingService = SchedulingService();
  List<ShiftModel> _draftShifts = [];
  bool _isGenerating = false;
  DateTime _selectedMonth = DateTime.now().add(const Duration(days: 15));

  Future<void> _generateDraft() async {
    setState(() => _isGenerating = true);
    try {
      final shifts = await _schedulingService.generateDraftSchedule(_selectedMonth);
      setState(() {
        _draftShifts = shifts;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _publish() async {
    if (_draftShifts.isEmpty) return;
    
    setState(() => _isGenerating = true);
    try {
      await _schedulingService.publishSchedule(_draftShifts);
      setState(() {
        _draftShifts = [];
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule Published Successfully! 📅'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.softGreen,
        ),
      );
    } catch (e) {
      setState(() => _isGenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context),
          _buildControlBar(),
          Expanded(
            child: _isGenerating
                ? const Center(child: CircularProgressIndicator())
                : _draftShifts.isEmpty
                    ? _buildEmptyState()
                    : _buildShiftsList(),
          ),
          if (_draftShifts.isNotEmpty && !_isGenerating) _buildPublishButton(),
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
            'Schedule Manager',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selected Month', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
              Text(DateFormat('MMMM yyyy').format(_selectedMonth), 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryPink)),
            ],
          ),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softPink,
              foregroundColor: AppColors.primaryPink,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Generate Draft'),
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
          Icon(Icons.calendar_today_outlined, size: 64, color: AppColors.textLight.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No draft generated yet', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Press "Generate Draft" to start', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildShiftsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _draftShifts.length,
      itemBuilder: (context, index) {
        final shift = _draftShifts[index];
        final isGara = shift.location == 'Gara';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: (isGara ? AppColors.softGreen : AppColors.softYellow).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(shift.location[0], 
                  style: TextStyle(fontWeight: FontWeight.bold, color: isGara ? Colors.green : Colors.orange)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shift.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${DateFormat('EEE, MMM dd').format(shift.date)} | ${DateFormat('HH:mm').format(shift.startTime)} - ${DateFormat('HH:mm').format(shift.endTime)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.softBlue, borderRadius: BorderRadius.circular(8)),
                child: Text('${shift.durationInHours}h', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPublishButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.green, Color(0xFF4CAF50)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: ElevatedButton(
          onPressed: _publish,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Approve & Publish', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
