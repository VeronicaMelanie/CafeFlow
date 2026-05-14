import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../consumption/data/consumption_repository.dart';
import '../../consumption/domain/consumption_model.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

class ConsumptionLogScreen extends ConsumerWidget {
  const ConsumptionLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final logsAsync = ref.watch(allConsumptionsProvider(now));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) return _buildEmptyState();
                
                final Map<String, int> totals = {};
                for (var log in logs) {
                  totals[log.productName] = (totals[log.productName] ?? 0) + log.quantity;
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionHeader('Monthly Summary', DateFormat('MMMM yyyy').format(now)),
                    const SizedBox(height: 12),
                    _buildSummaryGrid(totals),
                    const SizedBox(height: 32),
                    _buildSectionHeader('Detailed History', 'Recent entries'),
                    const SizedBox(height: 12),
                    ...logs.map((log) => _buildLogCard(log)),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
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
            'Consumption Logs',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      ],
    );
  }

  Widget _buildSummaryGrid(Map<String, int> totals) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: totals.entries.map((e) => _buildSummaryItem(e.key, e.value)).toList(),
      ),
    );
  }

  Widget _buildSummaryItem(String product, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product, style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryPink)),
      ],
    );
  }

  Widget _buildLogCard(ConsumptionModel log) {
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.softPink.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.coffee_outlined, color: AppColors.primaryPink, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Qty: ${log.quantity}', style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
              ],
            ),
          ),
          Text(DateFormat('dd MMM, HH:mm').format(log.date), style: const TextStyle(color: AppColors.textLight, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: AppColors.textLight.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No consumption logs yet', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
        ],
      ),
    );
  }
}

final allConsumptionsProvider = StreamProvider.family<List<ConsumptionModel>, DateTime>((ref, month) {
  return ref.watch(consumptionRepositoryProvider).getAllConsumptions(month);
});
