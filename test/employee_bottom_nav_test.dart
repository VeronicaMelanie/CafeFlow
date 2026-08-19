import 'package:fivetogo_scheduler/core/constants/app_colors.dart';
import 'package:fivetogo_scheduler/core/widgets/employee_bottom_nav_bar.dart';
import 'package:fivetogo_scheduler/features/scheduling/presentation/scheduling_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EmployeeBottomNavBar uses section accent colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              EmployeeBottomNavBar(
                selectedIndex: 2,
                onTabSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final statsLabel = tester.widget<Text>(find.text('Statistici'));
    expect(statsLabel.style?.color, AppColors.brandGreen);
  });

  testWidgets('EmployeeBottomNavBar animates active tab selection', (tester) async {
    var selected = 0;

    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              EmployeeBottomNavBar(
                selectedIndex: selected,
                onTabSelected: (index) => selected = index,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Program'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.people_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(selected, 1);
  });

  testWidgets('EmployeeBottomNavBar shows only active label inside pill', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (var index = 0; index < EmployeeNavTab.values.length; index++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EmployeeBottomNavBar(
                  selectedIndex: index,
                  onTabSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final activeTab = EmployeeNavTab.fromIndex(index);
      expect(find.text(activeTab.label), findsOneWidget);

      for (final tab in EmployeeNavTab.values) {
        if (tab != activeTab) {
          expect(find.text(tab.label), findsNothing);
        }
      }
    }
  });

  testWidgets('Schedule hides label on narrow width instead of truncating', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              EmployeeBottomNavBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Program'), findsNothing);
    expect(find.textContaining('...'), findsNothing);
    expect(find.byIcon(Icons.calendar_today_rounded), findsWidgets);
  });

  testWidgets('EmployeeBottomNavBar never uses ellipsis overflow on labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (var index = 0; index < EmployeeNavTab.values.length; index++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EmployeeBottomNavBar(
                  selectedIndex: index,
                  onTabSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.overflow == TextOverflow.ellipsis,
        ),
        findsNothing,
      );
      expect(find.textContaining('...'), findsNothing);
    }
  });

  testWidgets('Team Stats Profile labels stay fully visible on wide layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (var index = 1; index < EmployeeNavTab.values.length; index++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EmployeeBottomNavBar(
                  selectedIndex: index,
                  onTabSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final activeTab = EmployeeNavTab.fromIndex(index);
      expect(find.text(activeTab.label), findsOneWidget);
      expect(find.textContaining('...'), findsNothing);
    }
  });

  testWidgets('Active pill text stays inside pill bounds on wide layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              EmployeeBottomNavBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final pillFinder = find.byType(DecoratedBox).first;
    final labelFinder = find.text('Program');
    expect(labelFinder, findsOneWidget);

    final pillRect = tester.getRect(pillFinder);
    final labelRect = tester.getRect(labelFinder);
    expect(pillRect.contains(labelRect.topLeft), isTrue);
    expect(pillRect.contains(labelRect.bottomRight), isTrue);
  });

  test('EmployeeBottomNavLayout hides Schedule label when pill is too narrow', () {
    expect(
      EmployeeBottomNavLayout.activeLabelFits('Program', 42),
      isFalse,
    );
    expect(
      EmployeeBottomNavLayout.activeLabelFits('Echipă', 120),
      isTrue,
    );
  });

  testWidgets('EmployeeBottomNavBar has no per-item size animations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              EmployeeBottomNavBar(
                selectedIndex: 0,
                onTabSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedSize), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
    expect(find.byType(AnimatedPositioned), findsOneWidget);
  });

  test('employeeMainTabProvider defaults to schedule tab', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(employeeMainTabProvider), 0);

    container.read(employeeMainTabProvider.notifier).state = 2;
    expect(container.read(employeeMainTabProvider), 2);
  });

  test('EmployeeNavTab maps indices to brand accents', () {
    expect(EmployeeNavTab.schedule.accentColor, AppColors.brandMustard);
    expect(EmployeeNavTab.team.accentColor, AppColors.brandTurquoise);
    expect(EmployeeNavTab.stats.accentColor, AppColors.brandGreen);
    expect(EmployeeNavTab.profile.accentColor, AppColors.brandPurple);
  });
}
