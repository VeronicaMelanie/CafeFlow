import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/superadmin_guard.dart';
import '../../products/domain/product_model.dart';
import '../../products/presentation/product_providers.dart';
import '../data/superadmin_providers.dart';

class SuperadminProductsScreen extends ConsumerWidget {
  const SuperadminProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return SuperadminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        floatingActionButton: FloatingActionButton(
          onPressed: () => _add(context, ref, l10n),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Products', 'Produse'),
              subtitle: l10n.pick(
                'Add, hide, or delete catalog items',
                'Adaugi, ascunzi sau ștergi produse',
              ),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ref.watch(productsProvider).when(
                loading: () => const AppLoadingIndicator(),
                error: (error, _) => Center(child: Text(l10n.errorWith(error))),
                data: (products) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      return _ProductCard(product: products[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, L10n l10n) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pick('New product', 'Produs nou')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.pick('Product name', 'Numele produsului'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.pick('Cancel', 'Anulează')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.pick('Add', 'Adaugă')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(superadminRepositoryProvider).createProduct(name: name);
      ref.invalidate(productsProvider);
      ref.invalidate(superadminOverviewProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWith(e))),
        );
      }
    }
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return AppSurface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  product.isActive
                      ? l10n.pick('Active', 'Activ')
                      : l10n.pick('Hidden', 'Ascuns'),
                  style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: product.isActive,
            onChanged: (value) async {
              try {
                await ref.read(superadminRepositoryProvider).patchProduct(
                      id: product.id,
                      isActive: value,
                    );
                ref.invalidate(productsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorWith(e))),
                  );
                }
              }
            },
          ),
          IconButton(
            onPressed: () => _delete(context, ref, l10n),
            icon: const Icon(Icons.delete_outline, color: AppColors.brandRed),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, L10n l10n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pick('Delete product?', 'Ștergi produsul?')),
        content: Text(
          l10n.pick(
            'Also deletes consumption logs for this product.',
            'Șterge și jurnalele de consum pentru acest produs.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.pick('Cancel', 'Anulează')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.pick('Delete', 'Șterge')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(superadminRepositoryProvider).deleteProduct(product.id);
      ref.invalidate(productsProvider);
      ref.invalidate(superadminOverviewProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWith(e))),
        );
      }
    }
  }
}
