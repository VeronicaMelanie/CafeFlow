import 'package:fivetogo_scheduler/features/scheduling/data/scheduling_config_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/scheduling_config_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/utils/scheduling_month_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('availability window 20–30', () {
    test('September opens 20–30 August', () {
      final window = SchedulingMonthUtils.availabilityWindowFor(
        DateTime(2026, 9, 1),
      );
      expect(window.start, DateTime(2026, 8, 20));
      expect(window.end, DateTime(2026, 8, 30));
      expect(
        SchedulingMonthUtils.isAvailabilityWindowOpen(
          DateTime(2026, 9, 1),
          DateTime(2026, 8, 19),
        ),
        isFalse,
      );
      expect(
        SchedulingMonthUtils.isAvailabilityWindowOpen(
          DateTime(2026, 9, 1),
          DateTime(2026, 8, 20),
        ),
        isTrue,
      );
      expect(
        SchedulingMonthUtils.isAvailabilityWindowOpen(
          DateTime(2026, 9, 1),
          DateTime(2026, 8, 30),
        ),
        isTrue,
      );
      expect(
        SchedulingMonthUtils.isAvailabilityWindowOpen(
          DateTime(2026, 9, 1),
          DateTime(2026, 8, 31),
        ),
        isFalse,
      );
    });

    test('March window ends on 28 February in a non-leap year', () {
      final window = SchedulingMonthUtils.availabilityWindowFor(
        DateTime(2026, 3, 1),
      );
      expect(window.start, DateTime(2026, 2, 20));
      expect(window.end, DateTime(2026, 2, 28));
      expect(
        SchedulingMonthUtils.isAvailabilityWindowOpen(
          DateTime(2026, 3, 1),
          DateTime(2026, 2, 28),
        ),
        isTrue,
      );
    });

    test('March window ends on 29 February in a leap year', () {
      final window = SchedulingMonthUtils.availabilityWindowFor(
        DateTime(2028, 3, 1),
      );
      expect(window.start, DateTime(2028, 2, 20));
      expect(window.end, DateTime(2028, 2, 29));
    });
  });

  group('resolveMonthAccess', () {
    test('auto-opens during the window when there is no config row', () {
      final access = resolveMonthAccess(
        scheduleMonth: DateTime(2026, 9, 1),
        now: DateTime(2026, 8, 22),
      );
      expect(access.canEdit, isTrue);
      expect(access.windowOpen, isTrue);
      expect(access.bannerMessage, isNull);
    });

    test('stays closed before the 20th', () {
      final access = resolveMonthAccess(
        scheduleMonth: DateTime(2026, 9, 1),
        now: DateTime(2026, 8, 15),
      );
      expect(access.canEdit, isFalse);
      expect(access.windowUpcoming, isTrue);
      expect(access.bannerMessage, contains('20 aug'));
    });

    test('admin Close still blocks during the window', () {
      final access = resolveMonthAccess(
        scheduleMonth: DateTime(2026, 9, 1),
        now: DateTime(2026, 8, 22),
        config: const SchedulingConfigModel(
          id: 'sep',
          year: 2026,
          month: 9,
          schedulingEnabled: false,
        ),
      );
      expect(access.canEdit, isFalse);
      expect(access.bannerMessage, contains('închisă de manager'));
    });
  });
}
