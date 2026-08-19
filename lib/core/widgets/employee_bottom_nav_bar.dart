import 'dart:ui';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../l10n/l10n.dart';
import '../pwa/pwa_responsive.dart';
import '../theme/app_motion.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// Main employee bottom-navigation destinations.
enum EmployeeNavTab {
  schedule(
    Icons.calendar_today_rounded,
    AppColors.brandMustard,
  ),
  team(Icons.people_rounded, AppColors.brandTurquoise),
  stats(Icons.bar_chart_rounded, AppColors.brandGreen),
  profile(Icons.person_rounded, AppColors.brandPurple);

  const EmployeeNavTab(this.icon, this.accentColor);

  final IconData icon;
  final Color accentColor;

  String get label => labelFor(L10n.fallback);

  String labelFor(L10n l10n) {
    switch (this) {
      case EmployeeNavTab.schedule:
        return l10n.pick('Schedule', 'Program');
      case EmployeeNavTab.team:
        return l10n.pick('Team', 'Echipă');
      case EmployeeNavTab.stats:
        return l10n.pick('Stats', 'Statistici');
      case EmployeeNavTab.profile:
        return l10n.pick('Profile', 'Profil');
    }
  }

  static EmployeeNavTab fromIndex(int index) =>
      EmployeeNavTab.values[index.clamp(0, EmployeeNavTab.values.length - 1)];
}

/// Layout constants for content padding above the floating nav bar.
class EmployeeBottomNavMetrics {
  EmployeeBottomNavMetrics._();

  static const double barHeight = 68;

  static double bottomInset(BuildContext context) =>
      AppSpacing.md + PwaResponsive.bottomSafePadding(context);

  static double contentBottomPadding(BuildContext context) =>
      barHeight + bottomInset(context) + AppSpacing.lg;
}

/// Floating employee bottom navigation bar shared across main sections.
class EmployeeBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const EmployeeBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = EmployeeBottomNavMetrics.bottomInset(context);

    return Positioned(
      bottom: bottomInset,
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      child: Container(
        height: EmployeeBottomNavMetrics.barHeight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.pureWhite.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill + 7),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.6),
            width: 0.5,
          ),
          boxShadow: AppShadows.xl,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill + 7),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth =
                    constraints.maxWidth / EmployeeNavTab.values.length;
                final activeTab = EmployeeNavTab.fromIndex(selectedIndex);

                final pillWidth = tabWidth - (AppSpacing.xs * 2);

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedPositioned(
                      duration: AppMotion.normal,
                      curve: AppMotion.spring,
                      left: selectedIndex * tabWidth + AppSpacing.xs,
                      top: AppSpacing.sm,
                      bottom: AppSpacing.sm,
                      width: pillWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: activeTab.accentColor.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: _ActivePillContent(
                              tab: activeTab,
                              contentWidth:
                                  pillWidth - (AppSpacing.sm * 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < EmployeeNavTab.values.length; i++)
                          Expanded(
                            child: _EmployeeNavItem(
                              tab: EmployeeNavTab.values[i],
                              isSelected: selectedIndex == i,
                              onTap: () => onTabSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Layout rules for the active sliding pill label.
class EmployeeBottomNavLayout {
  EmployeeBottomNavLayout._();

  static const double activeIconSize = 22;
  static const double activeLabelFontSize = 12;
  static const FontWeight activeLabelFontWeight = FontWeight.w800;

  static TextStyle activeLabelStyle(Color color) => TextStyle(
        color: color,
        fontWeight: activeLabelFontWeight,
        fontSize: activeLabelFontSize,
      );

  /// True when [label] fits beside the active icon within [contentWidth].
  static bool activeLabelFits(
    String label,
    double contentWidth, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    if (contentWidth < activeIconSize) return false;

    final textPainter = TextPainter(
      text: TextSpan(text: label, style: activeLabelStyle(Colors.black)),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    const safetyMargin = 2.0;
    final requiredWidth =
        activeIconSize + AppSpacing.sm + textPainter.width + safetyMargin;
    return requiredWidth <= contentWidth;
  }
}

class _ActivePillContent extends StatelessWidget {
  final EmployeeNavTab tab;
  final double contentWidth;

  const _ActivePillContent({
    required this.tab,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final l10n = L10n.of(context);
    final showLabel = EmployeeBottomNavLayout.activeLabelFits(
      tab.labelFor(l10n),
      contentWidth,
      textScaler: textScaler,
    );
    final labelStyle =
        EmployeeBottomNavLayout.activeLabelStyle(tab.accentColor);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            tab.icon,
            size: EmployeeBottomNavLayout.activeIconSize,
            color: tab.accentColor,
          ),
          if (showLabel) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              tab.labelFor(l10n),
              maxLines: 1,
              softWrap: false,
              style: labelStyle,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeNavItem extends StatelessWidget {
  final EmployeeNavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmployeeNavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Center(
          child: Opacity(
            opacity: isSelected ? 0 : 1,
            child: Icon(
              tab.icon,
              size: 22,
              color: AppColors.textLight,
            ),
          ),
        ),
      ),
    );
  }
}
