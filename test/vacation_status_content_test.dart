import 'package:fivetogo_scheduler/features/auth/domain/user_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/vacation_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/vacation_status_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _user({DateTime? employmentDate}) {
  return UserModel(
    uid: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
    role: 'employee',
    workType: 'Full-time',
    monthlyTargetHours: 160,
    primaryLocation: 'Gara',
    secondaryLocation: 'Avantgarden',
    employmentDate: employmentDate,
  );
}

VacationModel _vacation({
  required String id,
  required String status,
  required DateTime requestedAt,
  DateTime? startDate,
  DateTime? endDate,
}) {
  return VacationModel(
    id: id,
    userId: 'user-1',
    userName: 'Test User',
    startDate: startDate ?? DateTime(2026, 8, 26),
    endDate: endDate ?? DateTime(2026, 8, 29),
    status: status,
    requestedAt: requestedAt,
  );
}

void main() {
  testWidgets('Approved tab only shows approved requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VacationStatusContent(
          user: _user(employmentDate: DateTime(2026, 1, 1)),
          vacations: [
            _vacation(
              id: 'approved',
              status: 'approved',
              requestedAt: DateTime(2026, 7, 16),
            ),
            _vacation(
              id: 'rejected',
              status: 'rejected',
              requestedAt: DateTime(2026, 6, 1),
            ),
          ],
          onRequestVacation: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('REJECTED'), findsNothing);

    await tester.tap(find.text('Rejected'));
    await tester.pumpAndSettle();

    expect(find.text('REJECTED'), findsOneWidget);
    expect(find.text('APPROVED'), findsNothing);
  });

  testWidgets('Rejected tab shows empty state when no rejected requests', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VacationStatusContent(
          user: _user(employmentDate: DateTime(2026, 1, 1)),
          vacations: [
            _vacation(
              id: 'approved',
              status: 'approved',
              requestedAt: DateTime(2026, 7, 16),
            ),
          ],
          onRequestVacation: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejected'));
    await tester.pumpAndSettle();

    expect(find.text('No rejected vacation requests'), findsOneWidget);
  });

  testWidgets('Missing employment date shows safe balance message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VacationStatusContent(
          user: _user(),
          vacations: const [],
          onRequestVacation: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('employment start date has not been configured'),
        findsOneWidget);
    expect(find.textContaining('days remaining'), findsNothing);
  });

  testWidgets('Request Vacation button is integrated and not a floating action button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VacationStatusContent(
          user: _user(employmentDate: DateTime(2026, 1, 1)),
          vacations: [
            _vacation(
              id: 'approved',
              status: 'approved',
              requestedAt: DateTime(2026, 7, 16),
            ),
          ],
          onRequestVacation: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Request Vacation'), findsOneWidget);

    final buttonRect = tester.getRect(find.text('Request Vacation'));
    final cardRect = tester.getRect(find.text('APPROVED'));
    expect(buttonRect.bottom <= cardRect.top, isTrue);
  });

  testWidgets('Vacation balance card shows earned and remaining values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VacationStatusContent(
          user: _user(employmentDate: DateTime(2025, 1, 1)),
          vacations: [
            _vacation(
              id: 'approved',
              status: 'approved',
              requestedAt: DateTime(2026, 1, 1),
              startDate: DateTime(2026, 2, 1),
              endDate: DateTime(2026, 2, 5),
            ),
          ],
          onRequestVacation: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vacation Balance'), findsOneWidget);
    expect(find.textContaining('days remaining'), findsOneWidget);
    expect(find.text('Used'), findsOneWidget);
    expect(find.text('Earned'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
