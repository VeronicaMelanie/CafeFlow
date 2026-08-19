import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/location_color_utils.dart';
import '../../../auth/domain/user_model.dart';
import '../../domain/shift_model.dart';
import '../../utils/scheduling_month_utils.dart';

/// Cafe rule: two people per cafe per day.
const int kMaxEmployeesPerLocationPerDay = 2;

Future<void> showRosterDaySheet({
  required BuildContext context,
  required DateTime date,
  required List<ShiftModel> Function() shiftsOfDay,
  required List<String> locationNames,
  required List<UserModel> employees,
  required Future<void> Function(ShiftModel shift) onRemove,
  required Future<void> Function(String location, UserModel employee) onAdd,
  Set<String> availableUserIds = const {},
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.pureWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final shifts = shiftsOfDay();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xl,
                AppSpacing.xxl,
                AppSpacing.huge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat(
                      'EEEE d MMMM',
                      L10n.of(context).isRo
                          ? null
                          : L10n.of(context).locale.languageCode,
                    ).format(date),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    L10n.of(context).pick(
                      'Max 2 people per cafe. Remove or add if there is a conflict.',
                      'Maxim 2 persoane pe cafenea. Scoate sau adaugă dacă e un conflict.',
                    ),
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final location in locationNames)
                    _LocationBlock(
                      date: date,
                      location: location,
                      shifts: shifts
                          .where((shift) => shift.location == location)
                          .toList(),
                      employees: employees,
                      allDayShifts: shifts,
                      onChanged: () => setModalState(() {}),
                      onRemove: onRemove,
                      onAdd: onAdd,
                    ),
                  _WaitlistBlock(
                    locationNames: locationNames,
                    employees: employees,
                    shifts: shifts,
                    availableUserIds: availableUserIds,
                    onAdd: onAdd,
                    onChanged: () => setModalState(() {}),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _LocationBlock extends StatelessWidget {
  const _LocationBlock({
    required this.date,
    required this.location,
    required this.shifts,
    required this.employees,
    required this.allDayShifts,
    required this.onChanged,
    required this.onRemove,
    required this.onAdd,
  });

  final DateTime date;
  final String location;
  final List<ShiftModel> shifts;
  final List<UserModel> employees;
  final List<ShiftModel> allDayShifts;
  final VoidCallback onChanged;
  final Future<void> Function(ShiftModel shift) onRemove;
  final Future<void> Function(String location, UserModel employee) onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = shifts.length < kMaxEmployeesPerLocationPerDay;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: LocationColorUtils.foregroundFor(location),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$location  ·  ${shifts.length}/$kMaxEmployeesPerLocationPerDay',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: LocationColorUtils.foregroundFor(location),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (shifts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                L10n.of(context).pick('No one on shift', 'Nimeni pe tură'),
                style: const TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
            ),
          for (final shift in shifts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shift.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${DateFormat('HH:mm').format(shift.startTime)}–${DateFormat('HH:mm').format(shift.endTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                  IconButton(
                    tooltip: L10n.of(context).pick('Remove', 'Scoate'),
                    onPressed: () async {
                      await onRemove(shift);
                      onChanged();
                    },
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.brandRed,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          if (canAdd)
            TextButton.icon(
              onPressed: () async {
                final employee = await _pickEmployee(
                  context,
                  date: date,
                  location: location,
                  employees: employees,
                  busyIds: {for (final shift in allDayShifts) shift.userId},
                );
                if (employee == null) return;
                await onAdd(location, employee);
                onChanged();
              },
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text(
                L10n.of(context).pick('Add to $location', 'Adaugă la $location'),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaitlistBlock extends StatelessWidget {
  const _WaitlistBlock({
    required this.locationNames,
    required this.employees,
    required this.shifts,
    required this.availableUserIds,
    required this.onAdd,
    required this.onChanged,
  });

  final List<String> locationNames;
  final List<UserModel> employees;
  final List<ShiftModel> shifts;
  final Set<String> availableUserIds;
  final Future<void> Function(String location, UserModel employee) onAdd;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (availableUserIds.isEmpty) return const SizedBox.shrink();
    final l10n = L10n.of(context);
    final busyIds = {for (final shift in shifts) shift.userId};
    final waiting = employees
        .where(
          (employee) =>
              availableUserIds.contains(employee.uid) &&
              !busyIds.contains(employee.uid),
        )
        .toList();
    if (waiting.isEmpty) return const SizedBox.shrink();

    final openLocations = locationNames
        .where(
          (location) =>
              shifts.where((shift) => shift.location == location).length <
              kMaxEmployeesPerLocationPerDay,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.pick(
            'Wanted this day, not placed (${waiting.length})',
            'Au vrut ziua, nu sunt puși (${waiting.length})',
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.pick(
            'Tap a cafe to place them if there is a free slot.',
            'Atinge o cafenea ca să-i pui, dacă mai e loc.',
          ),
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final employee in waiting)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    employee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (openLocations.isEmpty)
                  Text(
                    l10n.pick('Full', 'Complet'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  )
                else
                  for (final location in openLocations)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(location),
                        onPressed: () async {
                          await onAdd(location, employee);
                          onChanged();
                        },
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<UserModel?> _pickEmployee(
  BuildContext context, {
  required DateTime date,
  required String location,
  required List<UserModel> employees,
  required Set<String> busyIds,
}) {
  final free = employees
      .where((employee) => !busyIds.contains(employee.uid))
      .toList();
  if (free.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          L10n.of(context).pick(
            'Everyone is already on a shift that day.',
            'Toată lumea e deja pe tură în ziua asta.',
          ),
        ),
      ),
    );
    return Future<UserModel?>.value(null);
  }

  return showModalBottomSheet<UserModel>(
    context: context,
    backgroundColor: AppColors.pureWhite,
    builder: (context) {
      final l10n = L10n.of(context);
      final locale = l10n.isRo ? null : l10n.locale.languageCode;
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.pick(
                  'Who works at $location on ${DateFormat('d MMM', locale).format(date)}?',
                  'Cine lucrează la $location pe ${DateFormat('d MMM', locale).format(date)}?',
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            for (final employee in free)
              ListTile(
                title: Text(employee.name),
                subtitle: Text(employee.primaryLocation),
                onTap: () => Navigator.pop(context, employee),
              ),
          ],
        ),
      );
    },
  );
}

ShiftModel fullDayDraftShift({
  required UserModel employee,
  required DateTime date,
  required String location,
  String id = '',
  String status = 'pending',
}) {
  final start = DateTime(
    date.year,
    date.month,
    date.day,
    SchedulingMonthUtils.shopOpenHour,
  );
  final end = DateTime(
    date.year,
    date.month,
    date.day,
    SchedulingMonthUtils.shopCloseHour,
  );
  return ShiftModel(
    id: id,
    userId: employee.uid,
    userName: employee.name,
    date: date,
    startTime: start,
    endTime: end,
    type: 'FULL',
    location: location,
    status: status,
  );
}
