import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

import '../../../../core/theme/app_shadows.dart';

import '../../../../core/theme/app_spacing.dart';



class AvailabilityHoursSummary extends StatelessWidget {

  final double bookedHours;

  final double? monthlyTargetHours;



  const AvailabilityHoursSummary({

    super.key,

    required this.bookedHours,

    this.monthlyTargetHours,

  });



  @override

  Widget build(BuildContext context) {

    final target = monthlyTargetHours ?? 160.0;

    final remaining = (target - bookedHours).clamp(0.0, target);



    return Row(

      children: [

        Expanded(

          child: _StatTile(

            label: 'Submitted hours',

            value: '${bookedHours.toStringAsFixed(1)}h',

            color: AppColors.softPink,

            accent: AppColors.primaryPink,

          ),

        ),

        const SizedBox(width: AppSpacing.md),

        Expanded(

          child: _StatTile(

            label: 'Remaining to target',

            value: '${remaining.toStringAsFixed(1)}h',

            color: AppColors.softGreen,

            accent: const Color(0xFF2E7D32),

          ),

        ),

      ],

    );

  }

}



class _StatTile extends StatelessWidget {

  final String label;

  final String value;

  final Color color;

  final Color accent;



  const _StatTile({

    required this.label,

    required this.value,

    required this.color,

    required this.accent,

  });



  @override

  Widget build(BuildContext context) {

    return AnimatedSwitcher(

      duration: const Duration(milliseconds: 250),

      switchInCurve: Curves.easeOutCubic,

      switchOutCurve: Curves.easeInCubic,

      child: Container(

        key: ValueKey(value),

        padding: const EdgeInsets.all(AppSpacing.lg),

        decoration: BoxDecoration(

          color: color.withValues(alpha: 0.65),

          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),

          border: Border.all(

            color: color.withValues(alpha: 0.4),

            width: 0.5,

          ),

          boxShadow: AppShadows.xs,

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(

              label,

              style: TextStyle(

                fontSize: 11,

                color: AppColors.textDark.withValues(alpha: 0.55),

                fontWeight: FontWeight.w600,

              ),

            ),

            const SizedBox(height: AppSpacing.sm),

            Text(

              value,

              style: TextStyle(

                fontSize: 22,

                fontWeight: FontWeight.w800,

                color: accent,

                letterSpacing: -0.3,

              ),

            ),

          ],

        ),

      ),

    );

  }

}


