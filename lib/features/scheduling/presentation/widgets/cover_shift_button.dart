import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/shift_model.dart';
import '../scheduling_providers.dart';

class CoverShiftButton extends ConsumerWidget {
  const CoverShiftButton({super.key, required this.shift});

  final ShiftModel shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final pending = ref.watch(pendingCoverRequestsProvider).valueOrNull ?? [];
    final already = pending.any((item) => item.shiftId == shift.id);
    final isFuture = shift.endTime.isAfter(DateTime.now());
    if (!isFuture || shift.status != 'approved') {
      return const SizedBox.shrink();
    }

    if (already) {
      return Text(
        l10n.pick('Cover requested', 'Înlocuire cerută'),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textLight,
        ),
      );
    }

    return TextButton(
      onPressed: () => _confirm(context, ref),
      child: Text(l10n.pick("Can't work", 'Nu pot lucra')),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogL10n = L10n.of(context);
        return AlertDialog(
          title: Text(
            dialogL10n.pick("Can't work this shift?", 'Nu poți lucra această tură?'),
          ),
          content: Text(
            dialogL10n.pick(
              'Your manager and team will be notified for ${DateFormat('EEE d MMM', dialogL10n.isRo ? null : dialogL10n.locale.languageCode).format(shift.date)} at ${shift.location}.',
              'Managerul și echipa vor fi anunțați pentru ${DateFormat('EEE d MMM', dialogL10n.isRo ? null : dialogL10n.locale.languageCode).format(shift.date)} la ${shift.location}.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(dialogL10n.pick('Cancel', 'Anulează')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(dialogL10n.pick('Request cover', 'Cere înlocuire')),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    try {
      final name =
          ref.read(currentUserProvider).value?.name ??
          l10n.pick('A coworker', 'Un coleg');
      await ref.read(coverRequestRepositoryProvider).requestCover(
            shift: shift,
            employeeName: name,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.of(context).pick('Cover request sent.', 'Cererea de înlocuire a fost trimisă.'),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            L10n.of(context).pick(
              'Could not send the request: $e',
              'Cererea nu a putut fi trimisă: $e',
            ),
          ),
        ),
      );
    }
  }
}
