import 'package:fivetogo_scheduler/features/auth/domain/user_model.dart';
import 'package:fivetogo_scheduler/features/auth/presentation/auth_providers.dart';
import 'package:fivetogo_scheduler/features/scheduling/data/scheduling_config_repository.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/availability_model.dart';
import 'package:fivetogo_scheduler/features/scheduling/domain/shift_type.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/scheduling_providers.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/submit_availability_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  final scheduleMonth = DateTime(2026, 9, 1);
  final testUser = UserModel(
    uid: 'test-user',
    email: 'test@example.com',
    name: 'Test User',
    role: 'employee',
    workType: 'Full-time',
    monthlyTargetHours: 160,
    primaryLocation: 'Gara',
    secondaryLocation: 'Avantgarden',
  );

  const editableAccess = MonthSchedulingAccess(
    calendarMonthLocked: false,
    adminLockedMonth: false,
    schedulingEnabled: true,
    canEdit: true,
  );

  Widget buildTestApp({List<AvailabilityModel> entries = const []}) {
    return ProviderScope(
      overrides: [
        availabilityFocusedMonthProvider.overrideWith((ref) => scheduleMonth),
        currentUserProvider.overrideWith((ref) async => testUser),
        userAvailabilityForMonthProvider.overrideWith(
          (ref, month) => Stream.value(entries),
        ),
        monthSchedulingAccessProvider.overrideWith(
          (ref, month) => editableAccess,
        ),
      ],
      child: const MaterialApp(
        home: SubmitAvailabilityScreen(),
      ),
    );
  }

  Future<void> tapDay(WidgetTester tester, String dayLabel) async {
    final finder = find.text(dayLabel).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> selectFullDay(WidgetTester tester) async {
    expect(find.text('Toată ziua'), findsOneWidget);
    await tester.tap(find.text('Toată ziua'));
    await tester.pumpAndSettle();
  }

  Future<void> openCustomHoursSheet(WidgetTester tester) async {
    expect(find.text('Ore personalizate'), findsOneWidget);
    await tester.tap(find.text('Ore personalizate'));
    await tester.pumpAndSettle();
  }

  Finder fullDayCircleFor(String dayLabel) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration! as BoxDecoration).color == const Color(0xFF1F7A4D) &&
          find
              .descendant(
                of: find.byWidget(widget),
                matching: find.text(dayLabel),
              )
              .evaluate()
              .isNotEmpty,
    );
  }

  Finder customHoursCircleFor(String dayLabel) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
          (widget.decoration! as BoxDecoration).border != null &&
          find
              .descendant(
                of: find.byWidget(widget),
                matching: find.text(dayLabel),
              )
              .evaluate()
              .isNotEmpty,
    );
  }

  testWidgets('select Full Day shows solid green circle', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapDay(tester, '15');
    await selectFullDay(tester);

    expect(find.text('15'), findsWidgets);
    expect(fullDayCircleFor('15'), findsOneWidget);
    expect(customHoursCircleFor('15'), findsNothing);
  });

  testWidgets('select Custom Hours shows distinct lighter style', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapDay(tester, '15');
    await openCustomHoursSheet(tester);
    await tester.tap(find.text('Confirmă'));
    await tester.pumpAndSettle();

    expect(find.text('15'), findsWidgets);
    expect(customHoursCircleFor('15'), findsOneWidget);
    expect(fullDayCircleFor('15'), findsNothing);
  });

  testWidgets('edit Custom Hours to Full Day updates calendar style',
      (tester) async {
    final entries = [
      AvailabilityModel(
        id: 'custom-doc',
        userId: testUser.uid,
        date: DateTime(2026, 9, 9),
        shiftType: AvailabilityShiftType.customHours,
        customStartTime: DateTime(2026, 9, 9, 10, 0),
        customEndTime: DateTime(2026, 9, 9, 14, 0),
      ),
    ];

    await tester.pumpWidget(buildTestApp(entries: entries));
    await tester.pumpAndSettle();
    expect(customHoursCircleFor('9'), findsOneWidget);

    await tapDay(tester, '9');
    await tester.tap(find.text('Schimbă disponibilitatea'));
    await tester.pumpAndSettle();
    await selectFullDay(tester);

    expect(fullDayCircleFor('9'), findsOneWidget);
    expect(customHoursCircleFor('9'), findsNothing);
  });

  testWidgets('tapping selected day opens edit sheet instead of removing',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapDay(tester, '15');
    await selectFullDay(tester);
    expect(fullDayCircleFor('15'), findsOneWidget);

    await tapDay(tester, '15');
    expect(find.text('Schimbă disponibilitatea'), findsOneWidget);
    expect(find.text('Șterge disponibilitatea'), findsOneWidget);
  });

  testWidgets('edit flow can remove availability', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapDay(tester, '15');
    await selectFullDay(tester);
    expect(fullDayCircleFor('15'), findsOneWidget);

    await tapDay(tester, '15');
    await tester.tap(find.text('Șterge disponibilitatea'));
    await tester.pumpAndSettle();

    expect(fullDayCircleFor('15'), findsNothing);
    expect(find.text('15'), findsWidgets);
  });

  testWidgets('edit Full Day to Custom Hours updates calendar style',
      (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapDay(tester, '15');
    await selectFullDay(tester);
    expect(fullDayCircleFor('15'), findsOneWidget);

    await tapDay(tester, '15');
    await tester.tap(find.text('Schimbă disponibilitatea'));
    await tester.pumpAndSettle();
    await openCustomHoursSheet(tester);
    await tester.tap(find.text('Confirmă'));
    await tester.pumpAndSettle();

    expect(customHoursCircleFor('15'), findsOneWidget);
    expect(fullDayCircleFor('15'), findsNothing);
  });

  testWidgets('reload restores Full Day from server entries', (tester) async {
    final entries = [
      AvailabilityModel(
        id: 'full-doc',
        userId: testUser.uid,
        date: DateTime(2026, 9, 8),
        shiftType: AvailabilityShiftType.fullTime,
      ),
    ];

    await tester.pumpWidget(buildTestApp(entries: entries));
    await tester.pumpAndSettle();

    expect(fullDayCircleFor('8'), findsOneWidget);
  });

  testWidgets('reload restores Custom Hours from server entries',
      (tester) async {
    final entries = [
      AvailabilityModel(
        id: 'custom-doc',
        userId: testUser.uid,
        date: DateTime(2026, 9, 9),
        shiftType: AvailabilityShiftType.customHours,
        customStartTime: DateTime(2026, 9, 9, 16, 0),
        customEndTime: DateTime(2026, 9, 9, 18, 0),
      ),
    ];

    await tester.pumpWidget(buildTestApp(entries: entries));
    await tester.pumpAndSettle();

    expect(customHoursCircleFor('9'), findsOneWidget);
  });

  testWidgets('calendar page change keeps unsaved drafts', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapDay(tester, '15');
    await selectFullDay(tester);
    expect(fullDayCircleFor('15'), findsOneWidget);

    final calendar = tester.widget<TableCalendar>(find.byType(TableCalendar));
    calendar.onPageChanged?.call(DateTime(2026, 9, 1));
    await tester.pumpAndSettle();

    expect(fullDayCircleFor('15'), findsOneWidget);
  });
}
