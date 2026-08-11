import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_motion.dart';

/// Wraps tappable content with subtle press-in and optional hover scale.
class InteractiveScale extends StatefulWidget {
  const InteractiveScale({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.hoverScale = AppMotion.hoverScale,
    this.pressScale = AppMotion.pressScale,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double hoverScale;
  final double pressScale;
  final BorderRadius? borderRadius;

  @override
  State<InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<InteractiveScale> {
  bool _pressed = false;
  bool _hovered = false;

  double get _scale {
    if (!widget.enabled) return 1.0;
    if (_pressed) return widget.pressScale;
    if (_hovered) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _scale,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: widget.child,
    );

    if (widget.onTap == null || !widget.enabled) {
      return child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            splashColor: AppColors.primaryPink.withValues(alpha: 0.08),
            highlightColor: AppColors.primaryPink.withValues(alpha: 0.04),
            child: child,
          ),
        ),
      ),
    );
  }
}
