import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/superadmin_guard.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/superadmin_providers.dart';

class SuperadminUsersScreen extends ConsumerStatefulWidget {
  const SuperadminUsersScreen({super.key});

  @override
  ConsumerState<SuperadminUsersScreen> createState() =>
      _SuperadminUsersScreenState();
}

class _SuperadminUsersScreenState extends ConsumerState<SuperadminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final me = ref.watch(currentUserProvider).valueOrNull;

    return SuperadminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Users', 'Utilizatori'),
              subtitle: l10n.pick(
                'Change cafe role or delete accounts',
                'Schimbi rolul de cafenea sau ștergi conturi',
              ),
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                0,
              ),
              child: TextField(
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n.pick('Search name or email', 'Caută nume sau email'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.pureWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ref.watch(allUsersProvider).when(
                loading: () => const AppLoadingIndicator(),
                error: (error, _) => Center(child: Text(l10n.errorWith(error))),
                data: (users) {
                  final filtered = users.where((user) {
                    if (_query.isEmpty) return true;
                    return user.name.toLowerCase().contains(_query) ||
                        user.email.toLowerCase().contains(_query);
                  }).toList();
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _UserCard(
                        user: filtered[index],
                        isSelf: me?.uid == filtered[index].uid,
                        onChanged: _reload,
                      );
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

  void _reload() {
    ref.read(usersRepositoryProvider).invalidateCache();
    ref.invalidate(allUsersProvider);
    ref.invalidate(superadminOverviewProvider);
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.onChanged,
  });

  final UserModel user;
  final bool isSelf;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final postgresId = user.postgresId;
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(user.email, style: const TextStyle(color: AppColors.textLight)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.pick('Employee', 'Angajat')),
                      selected: user.role != 'admin',
                      onSelected: postgresId == null
                          ? null
                          : (_) => _setRole(context, ref, l10n, postgresId, 'employee'),
                    ),
                    ChoiceChip(
                      label: Text(l10n.pick('Cafe admin', 'Admin cafenea')),
                      selected: user.role == 'admin',
                      onSelected: postgresId == null
                          ? null
                          : (_) => _setRole(context, ref, l10n, postgresId, 'admin'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: l10n.pick('Delete', 'Șterge'),
                onPressed: isSelf || postgresId == null
                    ? null
                    : () => _confirmDelete(context, ref, l10n, postgresId),
                icon: const Icon(Icons.delete_outline, color: AppColors.brandRed),
              ),
            ],
          ),
          if (isSelf)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.pick(
                  'You cannot delete your own account.',
                  'Nu îți poți șterge propriul cont.',
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    String postgresId,
    String role,
  ) async {
    if (role == user.role) return;
    try {
      await ref
          .read(superadminRepositoryProvider)
          .patchUser(postgresId: postgresId, role: role);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWith(e))),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    String postgresId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pick('Delete this user?', 'Ștergi utilizatorul?')),
        content: Text(
          l10n.pick(
            'Removes their shifts, availability, vacations, and consumption logs. This cannot be undone.',
            'Șterge turele, disponibilitatea, concediile și consumul. Acțiunea nu se poate anula.',
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
      await ref.read(superadminRepositoryProvider).deleteUser(postgresId);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorWith(e))),
        );
      }
    }
  }
}
