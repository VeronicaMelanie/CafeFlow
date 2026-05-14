import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/consumption_repository.dart';
import '../domain/consumption_model.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/constants/app_colors.dart';

class ConsumptionEntryScreen extends ConsumerStatefulWidget {
  const ConsumptionEntryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumptionEntryScreen> createState() => _ConsumptionEntryScreenState();
}

class _ConsumptionEntryScreenState extends ConsumerState<ConsumptionEntryScreen> {
  String? _selectedProduct;
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Consumption',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep track of what you drink or eat during your shift.',
                    style: TextStyle(color: AppColors.textLight, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  _buildInputCard(),
                  const SizedBox(height: 40),
                  _buildPrimaryCTA(user?.uid),
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
            'Log Consumption',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: AppColors.shadowColor, blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product Detail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'What did you have?',
              hintText: 'e.g. Double Espresso, Croissant',
              prefixIcon: const Icon(Icons.restaurant_menu, color: AppColors.primaryPink),
              filled: true,
              fillColor: AppColors.softPink.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
            onChanged: (value) => setState(() => _selectedProduct = value),
          ),
          const SizedBox(height: 24),
          const Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQtyBtn(Icons.remove, _quantity > 1 ? () => setState(() => _quantity--) : null),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('$_quantity', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryPink)),
              ),
              _buildQtyBtn(Icons.add, () => setState(() => _quantity++)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.softPink : AppColors.borderLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: onTap != null ? AppColors.primaryPink : AppColors.textLight),
      ),
    );
  }

  Widget _buildPrimaryCTA(String? userId) {
    final bool isValid = _selectedProduct != null && _selectedProduct!.isNotEmpty && userId != null;
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: isValid ? AppColors.pinkGradient : null,
        color: isValid ? null : AppColors.textLight.withOpacity(0.2),
        borderRadius: BorderRadius.circular(30),
        boxShadow: isValid ? [
          BoxShadow(color: AppColors.primaryPink.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ] : null,
      ),
      child: ElevatedButton(
        onPressed: isValid ? () => _submit(userId) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: const Text('Add to My Log', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _submit(String userId) async {
    final consumption = ConsumptionModel(
      id: '',
      userId: userId,
      productName: _selectedProduct!,
      quantity: _quantity,
      date: DateTime.now(),
    );

    await ref.read(consumptionRepositoryProvider).addConsumption(consumption);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged! Enjoy your coffee! ☕'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryPink,
        ),
      );
    }
  }
}
