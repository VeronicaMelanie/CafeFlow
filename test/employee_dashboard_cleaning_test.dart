import 'package:fivetogo_scheduler/features/auth/domain/user_model.dart';
import 'package:fivetogo_scheduler/features/auth/presentation/auth_providers.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/shift_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/vacation_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/employee_dashboard.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/scheduling_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _employee() {
  return UserModel(
    uid: 'employee-1',
    email: 'employee@example.com',
    name: 'Veronica',
    role: 'employee',
    workType: 'Full-time',
    monthlyTargetHours: 160,
    primaryLocation: 'Gara',
    secondaryLocation: 'Avantgarden',
  );
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) async => _employee()),
        shiftRepositoryProvider.overrideWith((ref) => ShiftRepository.test()),
        vacationRepositoryProvider.overrideWith((ref) => VacationRepository.test()),
      ],
      child: const MaterialApp(home: EmployeeDashboard()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.scrollUntilVisible(
    find.text('Cleaning To-Do List'),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('Cleaning To-Do List card exists on employee dashboard',
      (tester) async {
    await _pumpDashboard(tester);
    expect(find.text('Cleaning To-Do List'), findsOneWidget);
    expect(find.text('Consumption'), findsOneWidget);
    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('Vacation Status'), findsOneWidget);
  });

  testWidgets('four dashboard cards use a balanced 2x2 grid', (tester) async {
    await _pumpDashboard(tester);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.childAspectRatio, 1);
  });
}
