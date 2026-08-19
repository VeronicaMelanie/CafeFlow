import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import 'app_locale.dart';

/// Space headers should leave on the right so content stays clear of [AppLanguageLayer].
const double kLanguageSwitchReserve = 108;

/// Compact EN / RO language toggle.
class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({
    super.key,
    this.onPink = false,
  });

  /// White-on-pink style for gradient headers.
  final bool onPink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    final selected = locale.languageCode;
    final bg = onPink ? Colors.white.withValues(alpha: 0.18) : AppColors.pureWhite;
    final border = onPink
        ? Colors.white.withValues(alpha: 0.35)
        : AppColors.borderLight.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: border, width: 0.5),
        boxShadow: onPink ? null : AppShadows.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: 'EN',
            selected: selected == 'en',
            onPink: onPink,
            onTap: () => ref.read(appLocaleProvider.notifier).setCode('en'),
          ),
          _Chip(
            label: 'RO',
            selected: selected == 'ro',
            onPink: onPink,
            onTap: () => ref.read(appLocaleProvider.notifier).setCode('ro'),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onPink,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool onPink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = onPink ? Colors.white : AppColors.brandGreen;
    final selectedFg = onPink ? AppColors.primaryPink : Colors.white;
    final idleFg = onPink ? Colors.white : AppColors.textLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: selected ? selectedFg : idleFg,
          ),
        ),
      ),
    );
  }
}

/// Single app-wide EN/RO control, drawn above every route.
class AppLanguageLayer extends StatelessWidget {
  const AppLanguageLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: padding.top + AppSpacing.sm,
          right: AppSpacing.xl,
          child: const LanguageSwitch(),
        ),
      ],
    );
  }
}
