import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fivetogo_scheduler/features/auth/domain/user_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/vacation_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/utils/vacation_balance_calculator.dart';
import 'package:fivetogo_scheduler/features/scheduling/utils/vacation_list_utils.dart';
import 'package:flutter_test/flutter_test.dart';

VacationModel _vacation({
  required String id,
  required DateTime requestedAt,
  required DateTime startDate,
  required DateTime endDate,
  String status = 'approved',
}) {
  return VacationModel(
    id: id,
    userId: 'user-1',
    userName: 'Test User',
    startDate: startDate,
    endDate: endDate,
    status: status,
    requestedAt: requestedAt,
  );
}

void main() {
  group('VacationBalanceCalculator.roundVacationDays', () {
    test('rounds 10.5 up to 11', () {
      expect(VacationBalanceCalculator.roundVacationDays(10.5), 11);
    });

    test('rounds 10.6 up to 11', () {
      expect(VacationBalanceCalculator.roundVacationDays(10.6), 11);
    });

    test('rounds 10.9 up to 11', () {
      expect(VacationBalanceCalculator.roundVacationDays(10.9), 11);
    });

    test('rounds 10.49 down to 10', () {
      expect(VacationBalanceCalculator.roundVacationDays(10.49), 10);
    });

    test('rounds 10.4 down to 10', () {
      expect(VacationBalanceCalculator.roundVacationDays(10.4), 10);
    });

    test('rounds 10.1 down to 10', () {
      expect(VacationBalanceCalculator.roundVacationDays(10.1), 10);
    });
  });

  group('VacationBalanceCalculator.calculate', () {
    test('1 month x 1.7 equals 2 earned days', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: const [],
        asOf: DateTime(2026, 2, 1),
      );

      expect(result.monthsWorked, 1);
      expect(result.earnedDays, 2);
      expect(result.remainingDays, 2);
    });

    test('3 months x 1.7 equals 5 earned days', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: const [],
        asOf: DateTime(2026, 4, 1),
      );

      expect(result.monthsWorked, 3);
      expect(result.earnedDays, 5);
    });

    test('6 months x 1.7 equals 10 earned days', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: const [],
        asOf: DateTime(2026, 7, 1),
      );

      expect(result.monthsWorked, 6);
      expect(result.earnedDays, 10);
    });

    test('10 months x 1.7 equals 17 earned days', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: const [],
        asOf: DateTime(2026, 11, 1),
      );

      expect(result.monthsWorked, 10);
      expect(result.earnedDays, 17);
    });

    test('approved vacation reduces remaining balance', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: [
          _vacation(
            id: 'v1',
            requestedAt: DateTime(2026, 3, 1),
            startDate: DateTime(2026, 4, 1),
            endDate: DateTime(2026, 4, 5),
            status: 'approved',
          ),
        ],
        asOf: DateTime(2026, 11, 1),
      );

      expect(result.earnedDays, 17);
      expect(result.usedDays, 5);
      expect(result.remainingDays, 12);
      expect(result.usageProgress, closeTo(5 / 17, 0.001));
    });

    test('rejected vacation does not reduce balance', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: [
          _vacation(
            id: 'v1',
            requestedAt: DateTime(2026, 3, 1),
            startDate: DateTime(2026, 4, 1),
            endDate: DateTime(2026, 4, 10),
            status: 'rejected',
          ),
        ],
        asOf: DateTime(2026, 11, 1),
      );

      expect(result.usedDays, 0);
      expect(result.remainingDays, 17);
    });

    test('pending vacation does not reduce balance', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: DateTime(2026, 1, 1),
        vacations: [
          _vacation(
            id: 'v1',
            requestedAt: DateTime(2026, 3, 1),
            startDate: DateTime(2026, 4, 1),
            endDate: DateTime(2026, 4, 10),
            status: 'pending',
          ),
        ],
        asOf: DateTime(2026, 11, 1),
      );

      expect(result.usedDays, 0);
      expect(result.remainingDays, 17);
    });

    test('missing employment date is handled safely', () {
      final result = VacationBalanceCalculator.calculate(
        employmentDate: null,
        vacations: const [],
        asOf: DateTime(2026, 8, 1),
      );

      expect(result.hasEmploymentDate, isFalse);
      expect(result.earnedDays, 0);
      expect(result.remainingDays, 0);
    });
  });

  group('VacationListUtils', () {
    test('sorts newest request date first', () {
      final sorted = VacationListUtils.sortByRequestDateNewestFirst([
        _vacation(
          id: 'old',
          requestedAt: DateTime(2026, 1, 10),
          startDate: DateTime(2026, 2, 1),
          endDate: DateTime(2026, 2, 3),
        ),
        _vacation(
          id: 'new',
          requestedAt: DateTime(2026, 7, 16),
          startDate: DateTime(2026, 8, 26),
          endDate: DateTime(2026, 8, 29),
        ),
      ]);

      expect(sorted.first.id, 'new');
      expect(sorted.last.id, 'old');
    });

    test('uses id as deterministic tie-breaker', () {
      final sameDay = DateTime(2026, 7, 16, 12);
      final sorted = VacationListUtils.sortByRequestDateNewestFirst([
        _vacation(
          id: 'a',
          requestedAt: sameDay,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 2),
        ),
        _vacation(
          id: 'z',
          requestedAt: sameDay,
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 2),
        ),
      ]);

      expect(sorted.first.id, 'z');
      expect(sorted.last.id, 'a');
    });

    test('filters approved and rejected separately', () {
      final vacations = [
        _vacation(
          id: 'approved',
          requestedAt: DateTime(2026, 1, 1),
          startDate: DateTime(2026, 2, 1),
          endDate: DateTime(2026, 2, 2),
          status: 'approved',
        ),
        _vacation(
          id: 'rejected',
          requestedAt: DateTime(2026, 1, 2),
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 2),
          status: 'rejected',
        ),
      ];

      expect(
        VacationListUtils.filterByStatus(vacations, 'approved').length,
        1,
      );
      expect(
        VacationListUtils.filterByStatus(vacations, 'rejected').length,
        1,
      );
    });
  });

  group('UserModel employment date', () {
    test('parses employmentDate from map', () {
      final user = UserModel.fromMap(
        {
          'email': 'a@b.com',
          'name': 'Alex',
          'role': 'employee',
          'workType': 'Full-time',
          'monthlyTargetHours': 160,
          'primaryLocation': 'Gara',
          'secondaryLocation': 'Avantgarden',
          'employmentDate': Timestamp.fromDate(DateTime(2025, 6, 1)),
        },
        'uid-1',
      );

      expect(user.employmentDate, DateTime(2025, 6, 1));
    });
  });
}
