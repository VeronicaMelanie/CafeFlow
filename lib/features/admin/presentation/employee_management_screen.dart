import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/admin_guard.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/screen_header.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../locations/presentation/location_providers.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends ConsumerState<EmployeeManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: l10n.pick('Our team', 'Echipa noastră'),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ref.watch(allUsersProvider).when(
                loading: () => const AppLoadingIndicator(),
                error: (error, _) => Center(
                  child: Text(
                    l10n.pick(
                      'Error loading employees',
                      'Eroare la încărcarea angajaților',
                    ),
                  ),
                ),
                data: (users) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.xl,
                    ),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildEmployeeCard(user);
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

  Widget _buildEmployeeCard(UserModel user) {
    final isAdmin = user.role == 'admin';
    final l10n = L10n.of(context);
    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.softPink,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primaryPink,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildBadge(
                user.primaryLocation,
                AppColors.softBlue,
                AppColors.primaryPink,
              ),
              if (user.secondaryLocation != null) ...[
                const SizedBox(width: 8),
                _buildBadge(
                  user.secondaryLocation!,
                  AppColors.softYellow,
                  Colors.orange,
                ),
              ],
              const Spacer(),
              _buildBadge(
                l10n.workTypeLabel(user.workType),
                AppColors.softGreen,
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.work_outline, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                user.employmentDate == null
                    ? l10n.pick(
                        'Start date: not set',
                        'Data angajării: nesetată',
                      )
                    : l10n.pick(
                        'Started: ${DateFormat('dd MMM yyyy', l10n.isRo ? null : l10n.locale.languageCode).format(user.employmentDate!)}',
                        'Început: ${DateFormat('dd MMM yyyy', l10n.isRo ? null : l10n.locale.languageCode).format(user.employmentDate!)}',
                      ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                l10n.pick(
                  'Target: ${user.monthlyTargetHours}h/month',
                  'Țintă: ${user.monthlyTargetHours}h/lună',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const Spacer(),
              if (!isAdmin)
                TextButton(
                  onPressed: () => _showEditDialog(user),
                  child: Text(
                    l10n.pick('Edit', 'Editează'),
                    style: TextStyle(
                      color: AppColors.primaryPink,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEditDialog(UserModel user) {
    final l10n = L10n.of(context);
    final TextEditingController nameController = TextEditingController(
      text: user.name,
    );
    final TextEditingController targetController = TextEditingController(
      text: user.monthlyTargetHours.toString(),
    );
    String selectedWorkType = user.workType;
    String selectedLocation = user.primaryLocation;
    DateTime? selectedEmploymentDate = user.employmentDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.pick('Edit employee', 'Editează angajat')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.pick('Name', 'Nume'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                decoration: InputDecoration(
                  labelText: l10n.pick(
                    'Monthly target hours',
                    'Ore țintă pe lună',
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.pick('Start date', 'Data începerii')),
                subtitle: Text(
                  selectedEmploymentDate == null
                      ? l10n.pick('Not set', 'Nesetată')
                      : DateFormat('dd MMM yyyy', l10n.isRo ? null : l10n.locale.languageCode)
                          .format(selectedEmploymentDate!),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedEmploymentDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedEmploymentDate = picked);
                  }
                },
              ),
              if (selectedEmploymentDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      setDialogState(() => selectedEmploymentDate = null);
                    },
                    child: Text(
                      l10n.pick('Clear start date', 'Șterge data angajării'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedWorkType,
                decoration: InputDecoration(
                  labelText: l10n.pick('Contract type', 'Tip contract'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Full-time',
                    child: Text(l10n.workTypeLabel('Full-time')),
                  ),
                  DropdownMenuItem(
                    value: 'Part-time',
                    child: Text(l10n.workTypeLabel('Part-time')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) selectedWorkType = value;
                },
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final locationNames = watchLocationNames(ref);
                  final value = locationNames.contains(selectedLocation)
                      ? selectedLocation
                      : (locationNames.isNotEmpty
                          ? locationNames.first
                          : selectedLocation);
                  return DropdownButtonFormField<String>(
                    value: locationNames.contains(value) ? value : null,
                    decoration: InputDecoration(
                      labelText: l10n.pick(
                        'Primary location',
                        'Locație principală',
                      ),
                    ),
                    items: locationNames.map((loc) {
                      return DropdownMenuItem(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) selectedLocation = newValue;
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.pick('Cancel', 'Anulează')),
          ),
          ElevatedButton(
            onPressed: () async {
              final postgresId = user.postgresId;
              if (postgresId == null || postgresId.isEmpty) {
                throw Exception('PostgreSQL user id is missing');
              }
              await ref.read(usersRepositoryProvider).updateUser(
                    postgresId: postgresId,
                    name: nameController.text,
                    monthlyTargetHours:
                        int.tryParse(targetController.text) ??
                            user.monthlyTargetHours,
                    contractType: selectedWorkType == 'Part-time'
                        ? 'part_time'
                        : 'full_time',
                    employmentDate: selectedEmploymentDate,
                    clearEmploymentDate: selectedEmploymentDate == null,
                  );
              ref.invalidate(allUsersProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(l10n.pick('Save', 'Salvează')),
          ),
        ],
      ),
      ),
    );
  }
}
