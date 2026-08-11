import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/interactive_scale.dart';

/// Shared CafeFlow auth layout: pink header, overlapping white card.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.subtitle,
    required this.cardChild,
    this.belowCard,
    this.bottomSection,
    this.showBack = false,
  });

  final String subtitle;
  final Widget cardChild;
  final Widget? belowCard;
  final Widget? bottomSection;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _AuthHeader(subtitle: subtitle, showBack: showBack),
              Transform.translate(
                offset: const Offset(0, -40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xxxl,
                      AppSpacing.xxl,
                      AppSpacing.xxxl,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(
                        color: AppColors.borderLight.withValues(alpha: 0.5),
                        width: 0.5,
                      ),
                      boxShadow: AppShadows.lg,
                    ),
                    child: cardChild,
                  ),
                ),
              ),
              if (belowCard != null) ...[
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: belowCard!,
                ),
              ],
              if (bottomSection != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: bottomSection!,
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.subtitle, required this.showBack});

  final String subtitle;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 64),
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(48),
        ),
      ),
      child: Column(
        children: [
          if (showBack)
            Align(
              alignment: Alignment.centerLeft,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Material(
                    color: AppColors.glassWhite,
                    child: InkWell(
                      onTap: () => Navigator.maybePop(context),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.glassWhiteStrong,
              shape: BoxShape.circle,
              boxShadow: AppShadows.sm,
            ),
            child: const Icon(
              Icons.emoji_food_beverage_rounded, // Coffee cup icon
              size: 44,
              color: AppColors.pureWhite,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'CafeFlow',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pink gradient pill button for auth forms.
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return InteractiveScale(
      enabled: enabled,
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: enabled ? (gradient ?? AppColors.warmGradient) : null,
          color: enabled ? null : AppColors.textLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          boxShadow: enabled ? AppShadows.coloredGlow(AppColors.brandMustard) : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                    strokeCap: StrokeCap.round,
                  ),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Grey rounded auth input matching the mockup.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.hint,
    required this.prefixIcon,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final String hint;
  final IconData prefixIcon;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: AppColors.brandTurquoise.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              color: AppColors.textLight.withValues(alpha: 0.85),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              color: AppColors.brandGreen,
              size: 22,
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide(
                color: AppColors.borderLight.withValues(alpha: 0.8),
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(
                color: AppColors.brandTurquoise,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.textLight.withValues(alpha: 0.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'OR CONTINUE WITH',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.textLight.withValues(alpha: 0.85),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.textLight.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthGoogleButton extends StatelessWidget {
  const AuthGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Google Account',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InteractiveScale(
      enabled: !isLoading && onPressed != null,
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: AppColors.borderLight.withValues(alpha: 0.9),
            width: 0.5,
          ),
          boxShadow: AppShadows.sm,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                      height: 22,
                      width: 22,
                      errorBuilder: (_, __, ___) => const Text(
                        'G',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onTap,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: AppColors.textLight),
          children: [
            TextSpan(text: prompt),
            TextSpan(
              text: actionLabel,
              style: const TextStyle(
                color: AppColors.brandGreen,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
