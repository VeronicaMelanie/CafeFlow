import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/consumption_repository.dart';
import '../domain/consumption_model.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';
import '../../locations/utils/location_catalog.dart';
import '../../products/domain/product_model.dart';
import '../../products/presentation/product_providers.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/interactive_scale.dart';

class ConsumptionEntryScreen extends ConsumerStatefulWidget {
  const ConsumptionEntryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConsumptionEntryScreen> createState() =>
      _ConsumptionEntryScreenState();
}

class _ConsumptionEntryScreenState
    extends ConsumerState<ConsumptionEntryScreen> {
  ProductModel? _selectedProduct;
  int _quantity = 1;
  String? _editingId;
  final TextEditingController _productQueryController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _filterPeriod = 'all';
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _productQueryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    ref.watch(locationsProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Column(
        children: [
          ScreenHeader(
            title: 'Log Consumption',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Consumption',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Keep track of what you drink or eat during your shift.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textLight,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  _buildInputCard(),
                  const SizedBox(height: AppSpacing.huge),
                  _buildPrimaryCTA(user?.uid),
                  const SizedBox(height: AppSpacing.huge),
                  _buildHistorySection(user?.uid),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return AppSurface(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Product Detail',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildProductSearch(),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Quantity',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQtyBtn(
                Icons.remove,
                _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryPink,
                  ),
                ),
              ),
              _buildQtyBtn(Icons.add, () => setState(() => _quantity++)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Date',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          InteractiveScale(
            onTap: () => _selectDate(),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.softPink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: AppColors.primaryPink,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Notes (optional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Add any notes...',
              filled: true,
              fillColor: AppColors.softPink.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearch() {
    final productsAsync = ref.watch(productsProvider);
    return productsAsync.when(
      loading: () => const AppSkeleton(height: 56, borderRadius: AppSpacing.radiusLg),
      error: (error, _) => const Text('Could not load products'),
      data: (products) {
        final query = _productQueryController.text.trim();
        final suggestions = _productSuggestions(products, query);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('product-search'),
              controller: _productQueryController,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {
                final text = _productQueryController.text.trim().toLowerCase();
                if (_selectedProduct != null &&
                    _selectedProduct!.name.toLowerCase() != text) {
                  _selectedProduct = null;
                }
              }),
              decoration: InputDecoration(
                labelText: 'What did you have?',
                hintText: products.isEmpty
                    ? 'No products available'
                    : 'Type to search, e.g. latte',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryPink,
                ),
                filled: true,
                fillColor: AppColors.softPink.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (query.isNotEmpty &&
                suggestions.isNotEmpty &&
                (_selectedProduct == null ||
                    _selectedProduct!.name.toLowerCase() !=
                        query.toLowerCase())) ...[
              const SizedBox(height: AppSpacing.sm),
              ...suggestions.map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Material(
                    color: AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: InkWell(
                      key: Key('product-suggestion-${product.id}'),
                      onTap: () => setState(() {
                        _selectedProduct = product;
                        _productQueryController.text = product.name;
                        _productQueryController.selection =
                            TextSelection.collapsed(
                          offset: product.name.length,
                        );
                      }),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_cafe_outlined,
                              size: 18,
                              color: AppColors.primaryPink,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(product.name)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (query.isNotEmpty &&
                _resolveProduct(products) == null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'No matching product. Keep typing or pick from the list.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],
          ],
        );
      },
    );
  }

  List<ProductModel> _productSuggestions(
    List<ProductModel> products,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final matches = products
        .where(
          (product) =>
              product.isActive &&
              product.name.toLowerCase().contains(needle),
        )
        .toList()
      ..sort((a, b) {
        final aExact = a.name.toLowerCase() == needle;
        final bExact = b.name.toLowerCase() == needle;
        if (aExact != bExact) return aExact ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return matches.take(8).toList();
  }

  ProductModel? _resolveProduct(List<ProductModel> products) {
    final needle = _productQueryController.text.trim().toLowerCase();
    if (needle.isEmpty) return null;
    if (_selectedProduct != null &&
        _selectedProduct!.name.toLowerCase() == needle) {
      return _selectedProduct;
    }
    final exact = [
      for (final product in products)
        if (product.isActive && product.name.toLowerCase() == needle) product,
    ];
    if (exact.length == 1) return exact.first;
    final partial = [
      for (final product in products)
        if (product.isActive && product.name.toLowerCase().contains(needle))
          product,
    ];
    if (partial.length == 1) return partial.first;
    return null;
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap) {
    return InteractiveScale(
      onTap: onTap,
      enabled: onTap != null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.softPink : AppColors.borderLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(
          icon,
          color: onTap != null ? AppColors.primaryPink : AppColors.textLight,
        ),
      ),
    );
  }

  Widget _buildPrimaryCTA(String? userId) {
    final bool isValid =
        _productQueryController.text.trim().isNotEmpty && userId != null;
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: isValid ? AppColors.pinkGradient : null,
        color: isValid ? null : AppColors.textLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: isValid ? AppShadows.coloredGlow(AppColors.primaryPink) : null,
      ),
      child: ElevatedButton(
        onPressed: isValid ? () => _submit(userId) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          ),
        ),
        child: Text(
          _editingId != null ? 'Update Entry' : 'Add to My Log',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(String? userId) {
    if (userId == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            _buildFilterDropdown(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        StreamBuilder<List<ConsumptionModel>>(
          stream: ref
              .read(consumptionRepositoryProvider)
              .getConsumptionsForUser(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoadingIndicator(size: 24);
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final consumptions = _filterConsumptions(snapshot.data ?? []);

            if (consumptions.isEmpty) {
              return const Text(
                'No consumptions logged yet',
                style: TextStyle(color: AppColors.textLight),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: consumptions.length,
              itemBuilder: (context, index) {
                final consumption = consumptions[index];
                return _buildConsumptionCard(consumption);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.6)),
        boxShadow: AppShadows.xs,
      ),
      child: DropdownButton<String>(
        value: _filterPeriod,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All Time')),
          DropdownMenuItem(value: 'today', child: Text('Today')),
          DropdownMenuItem(value: 'week', child: Text('This Week')),
          DropdownMenuItem(value: 'month', child: Text('This Month')),
        ],
        onChanged: (value) => setState(() => _filterPeriod = value!),
      ),
    );
  }

  List<ConsumptionModel> _filterConsumptions(
    List<ConsumptionModel> consumptions,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filterPeriod) {
      case 'today':
        return consumptions.where((c) => c.date.isAfter(today)).toList();
      case 'week':
        final weekAgo = today.subtract(const Duration(days: 7));
        return consumptions.where((c) => c.date.isAfter(weekAgo)).toList();
      case 'month':
        final monthAgo = today.subtract(const Duration(days: 30));
        return consumptions.where((c) => c.date.isAfter(monthAgo)).toList();
      default:
        return consumptions;
    }
  }

  Widget _buildConsumptionCard(ConsumptionModel consumption) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.softPink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.coffee, color: AppColors.primaryPink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  consumption.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${consumption.quantity}x • ${DateFormat('dd MMM, HH:mm').format(consumption.date)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
                if (consumption.notes != null && consumption.notes!.isNotEmpty)
                  Text(
                    consumption.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit,
              size: 18,
              color: AppColors.primaryPink,
            ),
            onPressed: () => _editConsumption(consumption),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _deleteConsumption(consumption.id),
          ),
        ],
      ),
    );
  }

  void _editConsumption(ConsumptionModel consumption) {
    setState(() {
      _editingId = consumption.id;
      _selectedProduct = ProductModel(
        id: consumption.id,
        name: consumption.productName,
        isActive: true,
      );
      _productQueryController.text = consumption.productName;
      _quantity = consumption.quantity;
      _notesController.text = consumption.notes ?? '';
    });
  }

  Future<void> _deleteConsumption(String id) async {
    try {
      await ref.read(consumptionRepositoryProvider).deleteConsumption(id);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _submit(String userId) async {
    final wasEditing = _editingId != null;
    final products = ref.read(productsProvider).valueOrNull ?? [];
    final product = _resolveProduct(products);
    if (product == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type a product name and pick it from the suggestions.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final locationName = ref.read(selectedLocationProvider);
    final locations = ref.read(locationsProvider).valueOrNull ?? [];
    final locationId = LocationCatalog.byName(locations, locationName)?.id;

    try {
      if (wasEditing) {
        await ref
            .read(consumptionRepositoryProvider)
            .updateConsumption(
              _editingId!,
              product.name,
              _quantity,
              _notesController.text,
            );
      } else {
        final consumption = ConsumptionModel(
          id: '',
          userId: userId,
          productName: product.name,
          quantity: _quantity,
          date: _selectedDate,
          notes: _notesController.text,
        );
        await ref.read(consumptionRepositoryProvider).addConsumption(
              consumption,
              locationId: locationId,
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: ${_humanizeSaveError(e)}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    _clearForm();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasEditing
                ? 'Entry updated!'
                : 'Logged! Enjoy your coffee! ☕',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryPink,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      lastDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _selectedProduct = null;
      _productQueryController.clear();
      _quantity = 1;
      _notesController.clear();
      _selectedDate = DateTime.now();
    });
  }

  String _humanizeSaveError(Object error) {
    if (error is ApiHttpException && error.message == 'invalid_consumption') {
      return 'could not match this product or location. Try another product name.';
    }
    return '$error';
  }
}
