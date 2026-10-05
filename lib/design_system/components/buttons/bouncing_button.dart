import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';

/// Scale-on-press wrapper for tappable chrome (home actions, icon tiles).
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool enableHaptic;

  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.enableHaptic = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null || _pressed) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _release();
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    _release();
  }

  void _release() {
    if (!_pressed || !mounted) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = KeroseneMotion.reduceMotion(context);
    final body = AnimatedScale(
      scale: _pressed && !reduceMotion ? KeroseneMotion.pressScale : 1.0,
      duration: KeroseneMotion.duration(context, KeroseneMotion.fast),
      curve: KeroseneMotion.standard,
      child: widget.child,
    );

    if (widget.onTap == null) return body;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        enabled: true,
        child: widget.tooltip != null
            ? Tooltip(message: widget.tooltip!, child: body)
            : body,
      ),
    );
  }
}

/// Legacy name — prefer [BouncingButton].
typedef BouncingButtonWrapper = BouncingButton;
