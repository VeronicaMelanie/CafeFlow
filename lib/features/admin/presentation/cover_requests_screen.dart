import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import 'calendar_schedule_screen.dart';

class CoverRequestsScreen extends ConsumerWidget {
  const CoverRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCoverRequestsProvider);
    final l10n = L10n.of(context);

    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Cover requests', 'Cereri de înlocuire'),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: pending.when(
                loading: () => const AppLoadingIndicator(),
                error: (e, _) => Center(child: Text(l10n.errorWith(e))),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.pick(
                          'No cover requests right now.',
                          'Nicio cerere de înlocuire acum.',
                        ),
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.pureWhite,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLg,
                          ),
                          border: Border.all(
                            color: AppColors.borderLight.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.employeeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('EEEE d MMMM', l10n.isRo ? null : l10n.locale.languageCode).format(item.date)} · ${item.location}',
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CalendarScheduleScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    l10n.pick('Edit schedule', 'Editează programul'),
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => ref
                                      .read(coverRequestRepositoryProvider)
                                      .markHandled(item.id),
                                  child: Text(l10n.pick('Done', 'Gata')),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
