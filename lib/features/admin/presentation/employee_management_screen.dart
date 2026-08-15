import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.offWhite,
        body: Column(
          children: [
            ScreenHeader(
              title: 'Our Team',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ref.watch(allUsersProvider).when(
                loading: () => const AppLoadingIndicator(),
                error: (error, _) =>
                    const Center(child: Text('Error loading employees')),
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
              _buildBadge(user.workType, AppColors.softGreen, Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.work_outline, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                user.employmentDate == null
                    ? 'Employment date: not set'
                    : 'Started: ${DateFormat('dd MMM yyyy').format(user.employmentDate!)}',
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
                'Target: ${user.monthlyTargetHours}h/month',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
              const Spacer(),
              if (!isAdmin)
                TextButton(
                  onPressed: () => _showEditDialog(user),
                  child: const Text(
                    'Edit',
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
        title: const Text('Edit Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Target Hours',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Employment Start Date'),
                subtitle: Text(
                  selectedEmploymentDate == null
                      ? 'Not set'
                      : DateFormat('dd MMM yyyy').format(selectedEmploymentDate!),
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
                    child: const Text('Clear employment date'),
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedWorkType,
                decoration: const InputDecoration(labelText: 'Work Type'),
                items: const ['Full-time', 'Part-time'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
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
                    decoration: const InputDecoration(
                      labelText: 'Primary Location',
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
            child: const Text('Cancel'),
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
            child: const Text('Save'),
          ),
        ],
      ),
      ),
    );
  }
}
