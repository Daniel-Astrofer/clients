import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';

import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/monochrome_theme.dart';

class PinEntryScaffold extends StatefulWidget {
  final String instruction;
  final int valueLength;
  final int maxLength;
  final String? error;
  final bool busy;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onConfirm;
  final String? confirmLabel;
  final Widget? footer;
  final VoidCallback? onCancel;

  const PinEntryScaffold({
    super.key,
    required this.instruction,
    required this.valueLength,
    required this.maxLength,
    required this.error,
    required this.busy,
    required this.onDigit,
    required this.onDelete,
    required this.onConfirm,
    this.confirmLabel,
    this.footer,
    this.enabled = true,
    this.onCancel,
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

    if (widget.valueLength != oldWidget.valueLength) {
      _isUpdatingController = true;
      if (widget.valueLength == 0) {
        _textController.clear();
      } else if (widget.valueLength < _textController.text.length) {
        _textController.text =
            _textController.text.substring(0, widget.valueLength);
      }
      _isUpdatingController = false;
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
      _textController.text = text.substring(0, widget.valueLength);
      _isUpdatingController = false;
      return;
    }

    if (_isUpdatingController) return;

    if (text.length > widget.valueLength) {
      for (int i = widget.valueLength; i < text.length; i++) {
        widget.onDigit(text[i]);
      }
      if (text.length == widget.maxLength) {
        _focusNode.unfocus();
      }
    } else if (text.length < widget.valueLength) {
      final diff = widget.valueLength - text.length;
      for (int i = 0; i < diff; i++) {
        widget.onDelete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compactWidth = size.width < 380;
    final instructionFontSize = compactWidth ? 31.0 : 36.0;

    // System back must match the cancel button so payment auth returns
    // rejectedOutcome consistently (no orphaned dialog / ugly error path).
    return PopScope(
      canPop: widget.onCancel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final cancel = widget.onCancel;
        if (cancel != null) {
          cancel();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_focusNode.hasFocus && widget.enabled && !widget.busy) {
            _focusNode.requestFocus();
          }
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Stack(
              children: [
                // Must stay in the tree with Opacity 0 so autofocus / requestFocus
                // open the keyboard. Visibility(visible: false) breaks input.
                Opacity(
                  opacity: 0,
                  child: SizedBox(
                    width: 1,
                    height: 1,
                    child: TextField(
                      focusNode: _focusNode,
                      controller: _textController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                        signed: false,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      obscureText: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      style: const TextStyle(color: Colors.transparent),
                      onChanged: _handleTextChanged,
                    ),
                  ),
                ),
                if (widget.onCancel != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: monoTextColor,
                        size: 28,
                      ),
                      onPressed: widget.onCancel,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          double dotSize = 48.0;
                          final maxDotWidth = dotSize * 1.5;
                          final spacing = dotSize * 0.25;
                          final padding = dotSize * 0.8;
                          final requiredWidth = widget.maxLength * maxDotWidth +
                              (widget.maxLength - 1) * spacing +
                              padding +
                              4.0;
                          if (requiredWidth > availableWidth) {
                            // Solves the equation: availableWidth = dotSize * (maxLength * 1.75 + 0.55) + 4.0
                            dotSize = (availableWidth - 4.0) /
                                (widget.maxLength * 1.75 + 0.55);
                            if (dotSize < 16) dotSize = 16;
                          }

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 60),
                              Text(
                                widget.instruction,
                                textAlign: TextAlign.center,
                                style: AppTypography.newsreader(
                                  color: monoTextColor,
                                  fontSize: instructionFontSize,
                                  fontWeight: FontWeight.w500,
                                  height: 1.15,
                                  letterSpacing: -0.35,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 48),
                              LoadingErrorBorderWrapper(
                                busy: widget.busy,
                                hasError: widget.error != null,
                                child: PinEntryDots(
                                  length: widget.valueLength,
                                  maxLength: widget.maxLength,
                                  dotSize: dotSize,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: AnimatedSwitcher(
                                  duration: KeroseneMotion.short,
                                  child: widget.error == null
                                      ? const SizedBox.shrink()
                                      : Text(
                                          widget.error!,
                                          key: ValueKey(widget.error),
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.red.shade400,
                                            height: 1.28,
                                            letterSpacing: 0,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 60),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final spacing = dotSize * 0.25;
    return Semantics(
      label: '$length de $total dígitos preenchidos',
      child: AnimatedContainer(
        duration: KeroseneMotion.short,
        curve: KeroseneMotion.standard,
        padding: EdgeInsets.symmetric(
          horizontal: dotSize * 0.4,
          vertical: dotSize * 0.3,
        ),
        decoration: BoxDecoration(
          color: monoSurfaceAltColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(total, (index) {
            final filled = index < length;
            return AnimatedContainer(
              duration: KeroseneMotion.short,
              curve: KeroseneMotion.standard,
              margin: EdgeInsets.only(right: index == total - 1 ? 0 : spacing),
              width: filled ? dotSize * 1.5 : dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: filled
                    ? monoTextColor
                    : monoFaintTextColor.withValues(alpha: 0.26),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
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
      duration: const Duration(milliseconds: 1400),
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
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
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
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                widget.hasError ? Colors.red.shade800 : monoBorderStrongColor,
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
            color2: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
            borderRadius: 999,
            strokeWidth: 2,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
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
      colors: [
        color1,
        color2,
        color1,
      ],
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
