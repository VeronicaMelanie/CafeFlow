import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../constants/app_colors.dart';
import '../l10n/l10n.dart';
import '../theme/app_spacing.dart';
import 'app_skeleton.dart';

class SuperadminGuard extends ConsumerWidget {
  const SuperadminGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (userModel) {
        if (userModel == null) {
          return const Scaffold(body: AppLoadingIndicator());
        }

        if (!userModel.isSuperadmin) {
          final l10n = L10n.of(context);
          return Scaffold(
            backgroundColor: AppColors.offWhite,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 40),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.pick(
                        'Developer access only',
                        'Acces doar pentru developeri',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: Text(l10n.pick('Back', 'Înapoi')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return child;
      },
      loading: () => const Scaffold(body: AppLoadingIndicator()),
      error: (e, st) => Scaffold(
        body: Center(child: Text(L10n.of(context).errorWith(e))),
      ),
    );
  }
}
