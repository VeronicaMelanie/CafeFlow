import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/superadmin_guard.dart';
import '../../locations/domain/location_model.dart';
import '../../locations/presentation/location_providers.dart';
import '../data/superadmin_providers.dart';

class SuperadminLocationsScreen extends ConsumerWidget {
  const SuperadminLocationsScreen({super.key});

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
              title: l10n.pick('Cafes', 'Cafenele'),
              subtitle: l10n.pick(
                'Add a cafe or hide it from the app',
                'Adaugi o cafenea sau o ascunzi din aplicație',
              ),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ref.watch(locationsProvider).when(
                loading: () => const AppLoadingIndicator(),
                error: (error, _) => Center(child: Text(l10n.errorWith(error))),
                data: (locations) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    itemCount: locations.length,
                    itemBuilder: (context, index) {
                      return _LocationCard(location: locations[index]);
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
        title: Text(l10n.pick('New cafe', 'Cafenea nouă')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.pick('Cafe name', 'Numele cafenelei'),
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
      await ref.read(superadminRepositoryProvider).createLocation(name: name);
      ref.invalidate(locationsProvider);
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

class _LocationCard extends ConsumerWidget {
  const _LocationCard({required this.location});

  final LocationModel location;

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
                  location.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  location.code,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: location.isActive,
            onChanged: (value) async {
              try {
                await ref.read(superadminRepositoryProvider).patchLocation(
                      id: location.id,
                      isActive: value,
                    );
                ref.invalidate(locationsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorWith(e))),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
