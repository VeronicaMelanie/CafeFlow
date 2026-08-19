import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/superadmin_guard.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../scheduling/data/vacation_repository.dart';
import '../../scheduling/presentation/scheduling_providers.dart';
import '../data/superadmin_providers.dart';

class SuperadminRecordsScreen extends ConsumerStatefulWidget {
  const SuperadminRecordsScreen({super.key});

  @override
  ConsumerState<SuperadminRecordsScreen> createState() =>
      _SuperadminRecordsScreenState();
}

class _SuperadminRecordsScreenState
    extends ConsumerState<SuperadminRecordsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _query = '';
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _tick++);
    ref.invalidate(superadminOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SuperadminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Records', 'Înregistrări'),
              subtitle: l10n.pick(
                'Delete shifts, availability, or vacations',
                'Ștergi ture, disponibilitate sau concedii',
              ),
              onBack: () => Navigator.pop(context),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.textDark,
              tabs: [
                Tab(text: l10n.pick('Shifts', 'Ture')),
                Tab(text: l10n.pick('Availability', 'Disponibilitate')),
                Tab(text: l10n.pick('Vacation', 'Concedii')),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.xl,
                0,
              ),
              child: TextField(
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: l10n.pick('Search', 'Caută'),
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
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ShiftsTab(query: _query, tick: _tick, onChanged: _reload),
                  _AvailabilityTab(
                    query: _query,
                    tick: _tick,
                    onChanged: _reload,
                  ),
                  _VacationsTab(query: _query, tick: _tick, onChanged: _reload),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, L10n l10n) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.pick('Delete this record?', 'Ștergi înregistrarea?')),
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
      ) ??
      false;
}

class _ShiftsTab extends ConsumerWidget {
  const _ShiftsTab({
    required this.query,
    required this.tick,
    required this.onChanged,
  });

  final String query;
  final int tick;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final future = ref.watch(shiftRepositoryProvider).getAllShifts();
    return FutureBuilder(
      key: ValueKey('shifts-$tick'),
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(child: Text(l10n.errorWith(snapshot.error!)))
              : const AppLoadingIndicator();
        }
        final format = DateFormat('dd.MM.yyyy', l10n.isRo ? null : l10n.locale.languageCode);
        var items = snapshot.data!;
        items = [...items]..sort((a, b) => b.date.compareTo(a.date));
        if (query.isNotEmpty) {
          items = items
              .where(
                (shift) =>
                    shift.userName.toLowerCase().contains(query) ||
                    shift.location.toLowerCase().contains(query),
              )
              .toList();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final shift = items[index];
            return AppSurface(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${shift.userName} · ${format.format(shift.date)} · ${shift.location}',
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (!await _confirm(context, l10n)) return;
                      try {
                        await ref
                            .read(shiftRepositoryProvider)
                            .deleteShift(shift.id);
                        onChanged();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.errorWith(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.brandRed,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AvailabilityTab extends ConsumerWidget {
  const _AvailabilityTab({
    required this.query,
    required this.tick,
    required this.onChanged,
  });

  final String query;
  final int tick;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final users = {
      for (final user in ref.watch(allUsersProvider).valueOrNull ?? const [])
        user.uid: user.name,
    };
    final future = ref.watch(availabilityRepositoryProvider).getAllAvailability();
    return FutureBuilder(
      key: ValueKey('avail-$tick'),
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(child: Text(l10n.errorWith(snapshot.error!)))
              : const AppLoadingIndicator();
        }
        final format = DateFormat(
          'dd.MM.yyyy',
          l10n.isRo ? null : l10n.locale.languageCode,
        );
        var items = [...snapshot.data!]
          ..sort((a, b) => b.date.compareTo(a.date));
        if (query.isNotEmpty) {
          items = items.where((row) {
            final name = users[row.userId] ?? '';
            return name.toLowerCase().contains(query);
          }).toList();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final row = items[index];
            final name = users[row.userId] ?? row.userId;
            return AppSurface(
              child: Row(
                children: [
                  Expanded(child: Text('$name · ${format.format(row.date)}')),
                  IconButton(
                    onPressed: () async {
                      if (!await _confirm(context, l10n)) return;
                      try {
                        await ref
                            .read(availabilityRepositoryProvider)
                            .deleteAvailability(row.id);
                        onChanged();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.errorWith(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.brandRed,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VacationsTab extends ConsumerWidget {
  const _VacationsTab({
    required this.query,
    required this.tick,
    required this.onChanged,
  });

  final String query;
  final int tick;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final future = ref.watch(vacationRepositoryProvider).getAllVacations();
    return FutureBuilder(
      key: ValueKey('vac-$tick'),
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(child: Text(l10n.errorWith(snapshot.error!)))
              : const AppLoadingIndicator();
        }
        final format = DateFormat(
          'dd.MM.yyyy',
          l10n.isRo ? null : l10n.locale.languageCode,
        );
        var items = [...snapshot.data!]
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
        if (query.isNotEmpty) {
          items = items
              .where((row) => row.userName.toLowerCase().contains(query))
              .toList();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final row = items[index];
            return AppSurface(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${row.userName} · ${format.format(row.startDate)} – ${format.format(row.endDate)} · ${row.status}',
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      if (!await _confirm(context, l10n)) return;
                      try {
                        await ref
                            .read(superadminRepositoryProvider)
                            .deleteVacation(row.id);
                        onChanged();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.errorWith(e))),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.brandRed,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
