import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:kerosene/design_system/components/auth/auth_primary_cta.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/auth/presentation/widgets/auth_motion.dart';

import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';

class PinEntryScaffold extends StatefulWidget {
  final String instruction;
  final String? subtitle;
  final int valueLength;
  final int maxLength;
  final String? error;
  final bool busy;
  final String? busyLabel;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;
  final String? confirmLabel;
  final Widget? footer;
  final VoidCallback? onCancel;
  final Widget? background;

  const PinEntryScaffold({
    super.key,
    required this.instruction,
    this.subtitle,
    required this.valueLength,
    required this.maxLength,
    required this.error,
    required this.busy,
    this.busyLabel,
    required this.onDigit,
    required this.onDelete,
    required this.onConfirm,
    this.confirmLabel,
    this.footer,
    this.enabled = true,
    this.onCancel,
    this.background,
  });

  @override
  State<PinEntryScaffold> createState() => _PinEntryScaffoldState();
}

class _PinEntryScaffoldState extends State<PinEntryScaffold> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isUpdatingController = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PinEntryScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.valueLength < _textController.text.length) {
      _isUpdatingController = true;
      if (widget.valueLength == 0) {
        _textController.clear();
      } else if (widget.valueLength < _textController.text.length) {
        _textController.text = _textController.text.substring(
          0,
          widget.valueLength,
        );
      }
      _isUpdatingController = false;
    }

    if (widget.error != null && widget.error != oldWidget.error) {
      HapticFeedback.mediumImpact();
    }

    if (widget.busy && !oldWidget.busy) {
      _focusNode.unfocus();
    }

    if (!widget.busy && oldWidget.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged(String text) {
    if (!widget.enabled || widget.busy) {
      _isUpdatingController = true;
      _textController.text = '0' * widget.valueLength;
      _isUpdatingController = false;
      return;
    }

    if (_isUpdatingController) return;

    if (text.length > widget.valueLength) {
      for (int i = widget.valueLength; i < text.length; i++) {
        widget.onDigit(text[i]);
      }
    } else if (text.length < widget.valueLength) {
      final diff = widget.valueLength - text.length;
      for (int i = 0; i < diff; i++) {
        widget.onDelete();
      }
    }
  }

  void _confirm() {
    if (!widget.enabled || widget.busy) return;
    HapticFeedback.selectionClick();
    widget.onConfirm?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mono = MonochromeColors.of(context);
    return PopScope(
      canPop: widget.onCancel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel?.call();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_focusNode.hasFocus && widget.enabled && !widget.busy) {
            _focusNode.requestFocus();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.background != null) widget.background!,
            Scaffold(
              backgroundColor: widget.background != null
                  ? Colors.transparent
                  : mono.background,
              body: SafeArea(
                child: Stack(
                  children: [
                // Keep the native secure numeric input mounted. Removing it
                // would also remove keyboard, hardware-key and autofill support.
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: TextField(
                      key: const ValueKey('pin-secure-input'),
                      focusNode: _focusNode,
                      controller: _textController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.maxLength),
                      ],
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      style: const TextStyle(color: Colors.transparent),
                      onChanged: _handleTextChanged,
                      onSubmitted: (_) => _confirm(),
                    ),
                  ),
                ),
                LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 420,
                          minHeight: math.max(0, constraints.maxHeight - 64),
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              AnimatedSwitcher(
                                duration: KeroseneMotion.duration(
                                    context, KeroseneMotion.short),
                                child: Text(
                                  widget.instruction,
                                  key: ValueKey(widget.instruction),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.h1.copyWith(
                                    color: mono.text,
                                    fontSize:
                                        constraints.maxWidth < 380 ? 26 : 28,
                                    fontWeight: FontWeight.w300,
                                    height: 1.25,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  widget.subtitle!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: mono.mutedText,
                                    fontSize: 14,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Center(
                                child: AuthMotionShake(
                                  key: const ValueKey('pin-error-motion'),
                                  triggerKey: widget.error?.hashCode ?? 0,
                                  enabled: widget.error != null,
                                  child: LoadingErrorBorderWrapper(
                                    busy: widget.busy,
                                    hasError: widget.error != null,
                                    child: PinEntryDots(
                                      length: widget.valueLength,
                                      maxLength: widget.maxLength,
                                      dotSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 40),
                                child: AnimatedSwitcher(
                                  duration: KeroseneMotion.duration(
                                      context, KeroseneMotion.short),
                                  child: widget.busy && widget.busyLabel != null
                                      ? Semantics(
                                          key: const ValueKey('pin-working'),
                                          liveRegion: true,
                                          child: Text(
                                            widget.busyLabel!,
                                            textAlign: TextAlign.center,
                                            style:
                                                AppTypography.bodySmall.copyWith(
                                              color: mono.mutedText,
                                              fontSize: 14,
                                            ),
                                          ),
                                        )
                                      : widget.error == null
                                          ? const SizedBox.shrink()
                                          : Semantics(
                                              key: ValueKey(widget.error),
                                              liveRegion: true,
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  KeroseneIcon(
                                                    KeroseneIcons.error,
                                                    size: 18,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      widget.error!,
                                                      textAlign: TextAlign.center,
                                                      style: AppTypography
                                                          .bodySmall
                                                          .copyWith(
                                                        color: mono.text,
                                                        fontSize: 14,
                                                        height: 1.45,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                ),
                              ),
                              const Spacer(),
                              if (widget.onConfirm != null)
                                AuthPrimaryCta(
                                  label: widget.confirmLabel ??
                                      MaterialLocalizations.of(context)
                                          .okButtonLabel,
                                  onPressed: widget.enabled && !widget.busy
                                      ? _confirm
                                      : null,
                                  haptic: false,
                                  backgroundColor: mono.text,
                                  foregroundColor: mono.background,
                                ),
                              if (widget.footer != null) ...[
                                const SizedBox(height: 16),
                                widget.footer!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (widget.onCancel != null)
                  Positioned(
                    top: 8,
                    left: 16,
                    child: IconButton(
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      icon: KeroseneIcon(
                        KeroseneIcons.arrowBack,
                        color: mono.text,
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onCancel?.call();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
  }
}

class PinEntryDots extends StatelessWidget {
  final int length;
  final int maxLength;
  final double dotSize;

  const PinEntryDots({
    super.key,
    required this.length,
    required this.maxLength,
    this.dotSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    final total = maxLength.clamp(4, 8);
    final spacing = dotSize * 1.1;
    return Semantics(
      label: context.tr.pinEntryDigitsFilled(length, total),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: KeroseneMotion.duration(context, KeroseneMotion.short),
            curve: KeroseneMotion.standard,
            padding: EdgeInsets.symmetric(
              horizontal: dotSize * 1.6,
              vertical: dotSize * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(total, (index) {
                final filled = index < length;
                return AnimatedContainer(
                  duration:
                      KeroseneMotion.duration(context, KeroseneMotion.short),
                  curve: KeroseneMotion.standard,
                  margin:
                      EdgeInsets.only(right: index == total - 1 ? 0 : spacing),
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: filled
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingErrorBorderWrapper extends StatefulWidget {
  final Widget child;
  final bool busy;
  final bool hasError;

  const LoadingErrorBorderWrapper({
    super.key,
    required this.child,
    required this.busy,
    required this.hasError,
  });

  @override
  State<LoadingErrorBorderWrapper> createState() =>
      _LoadingErrorBorderWrapperState();
}

class _LoadingErrorBorderWrapperState extends State<LoadingErrorBorderWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.pinSuccess,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(covariant LoadingErrorBorderWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.busy != oldWidget.busy) {
      _syncSpin();
    }
  }

  void _syncSpin() {
    final allow = widget.busy &&
        TickerMode.valuesOf(context).enabled &&
        !KeroseneMotion.reduceMotion(context);
    if (allow) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else if (_rotationController.isAnimating) {
      _rotationController.stop(canceled: false);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowSpin = widget.busy &&
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    if (!allowSpin) {
      return AnimatedContainer(
        duration:
            KeroseneMotion.duration(context, KeroseneMotion.pinTransition),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: widget.hasError
                ? Theme.of(context).colorScheme.error
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _rotationController,
      child: widget.child,
      builder: (context, childWidget) {
        return CustomPaint(
          painter: SpinningBorderPainter(
            animationValue: _rotationController.value,
            color1: Theme.of(context).colorScheme.onSurface,
            color2: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.15),
            borderRadius: 999,
            strokeWidth: 2,
          ),
          child: AnimatedContainer(
            duration:
                KeroseneMotion.duration(context, KeroseneMotion.pinTransition),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.transparent, width: 2),
            ),
            child: childWidget,
          ),
        );
      },
    );
  }
}

class SpinningBorderPainter extends CustomPainter {
  final double animationValue;
  final Color color1;
  final Color color2;
  final double strokeWidth;
  final double borderRadius;

  SpinningBorderPainter({
    required this.animationValue,
    required this.color1,
    required this.color2,
    this.strokeWidth = 2.0,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final gradient = SweepGradient(
      center: Alignment.center,
      transform: GradientRotation(animationValue * 2 * 3.141592653589793),
      colors: [color1, color2, color1],
      stops: const [0.0, 0.5, 1.0],
    );

    paint.shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant SpinningBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
