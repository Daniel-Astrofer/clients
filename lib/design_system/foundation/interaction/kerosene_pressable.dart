import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';

/// A small, consistent press treatment for financial surfaces.
///
/// Native ink remains the primary affordance. The short scale response gives
/// touch users an immediate acknowledgement without adding a decorative
/// animation or introducing a new interaction pattern per screen.
class KerosenePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BorderRadius? borderRadius;
  final bool haptic;
  final bool enabled;

  const KerosenePressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius,
    this.haptic = true,
    this.enabled = true,
  });

  @override
  State<KerosenePressable> createState() => _KerosenePressableState();
}

class _KerosenePressableState extends State<KerosenePressable> {
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onPressed != null;

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (!_interactive) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final duration = KeroseneMotion.duration(context, KeroseneMotion.fast);
    final radius = widget.borderRadius ?? BorderRadius.zero;

    return Semantics(
      button: true,
      enabled: _interactive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _interactive ? _handleTap : null,
          onHighlightChanged: _setPressed,
          borderRadius: radius,
          child: AnimatedScale(
            scale: _pressed ? KeroseneMotion.pressScale : 1,
            duration: duration,
            curve: KeroseneMotion.standard,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
