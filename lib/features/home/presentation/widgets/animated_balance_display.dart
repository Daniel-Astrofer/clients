import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';

/// Balance amount with optional digit-roll (odometer) for **large value changes**.
///
/// Policies (home redesign):
/// - [animateInitialValue]: short ceremony spin on first mount only (session).
/// - [suppressRoll]: force static digits (e.g. while switching ledger tabs).
/// - Updates roll only when `|Δ balance| >= [largeDeltaThreshold]`.
class AnimatedBalanceDisplay extends StatefulWidget {
  final double balance;
  final TextStyle style;
  final int decimalPlaces;
  final bool enableFlash;
  final String? prefix;
  final bool isHidden;
  final String locale;
  final double decimalScaleFactor;
  final double separatorScaleFactor;
  final double digitWidthFactor;
  final double characterSpacing;
  final VoidCallback? onDecimalTap;

  /// Short odometer spin when this widget first mounts (session ceremony).
  final bool animateInitialValue;

  /// When true, never roll digits (view swipe / context change).
  final bool suppressRoll;

  /// Minimum absolute BTC change to trigger update odometer.
  final double largeDeltaThreshold;

  const AnimatedBalanceDisplay({
    super.key,
    required this.balance,
    required this.style,
    this.decimalPlaces = 8,
    this.enableFlash = false,
    this.prefix,
    this.isHidden = false,
    this.locale = 'en_US',
    this.decimalScaleFactor = 0.5,
    this.separatorScaleFactor = 0.7,
    this.digitWidthFactor = 0.64,
    this.characterSpacing = 0.8,
    this.onDecimalTap,
    this.animateInitialValue = false,
    this.suppressRoll = false,
    this.largeDeltaThreshold = 0.000001,
  });

  @override
  State<AnimatedBalanceDisplay> createState() => _AnimatedBalanceDisplayState();
}

class _AnimatedBalanceDisplayState extends State<AnimatedBalanceDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _flashController;
  late Animation<double> _flashOpacity;
  late String _visibleText;
  late _BalanceCharacterLayout _characterLayout;
  Color _flashColor = Colors.green;

  /// Generation bumps when we want digits to re-bind without rolling.
  int _layoutGeneration = 0;
  double _lastBalance = 0;
  bool _allowRollOnThisUpdate = false;

  @override
  void initState() {
    super.initState();
    _lastBalance = widget.balance;
    _allowRollOnThisUpdate = widget.animateInitialValue && !widget.suppressRoll;
    _refreshCharacterLayout();
    _flashController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.ceremonial,
      value: 1.0,
    );
    _flashOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _flashController, curve: KeroseneMotion.standard),
    );
  }

  @override
  void didUpdateWidget(AnimatedBalanceDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final balanceChanged = widget.balance != oldWidget.balance;
    final formatChanged = widget.decimalPlaces != oldWidget.decimalPlaces ||
        widget.prefix != oldWidget.prefix ||
        widget.isHidden != oldWidget.isHidden ||
        widget.locale != oldWidget.locale;

    if (balanceChanged ||
        formatChanged ||
        widget.suppressRoll != oldWidget.suppressRoll) {
      final delta = (widget.balance - _lastBalance).abs();
      final largeDelta = delta >= widget.largeDeltaThreshold;
      // Roll only on real large balance moves, never when suppressRoll (tab swipe).
      _allowRollOnThisUpdate = !widget.suppressRoll &&
          !widget.isHidden &&
          balanceChanged &&
          largeDelta &&
          !formatChanged;

      if (formatChanged || widget.suppressRoll) {
        // Force digit widgets to accept new glyphs without animating from old.
        _layoutGeneration++;
      }

      _lastBalance = widget.balance;
      _refreshCharacterLayout();

      if (widget.enableFlash &&
          balanceChanged &&
          largeDelta &&
          !widget.isHidden) {
        _flashColor = widget.balance > oldWidget.balance
            ? AppColors.hexFF00FF94
            : AppColors.hexFFFF0055;
        _flashController.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  void _refreshCharacterLayout() {
    _visibleText = widget.isHidden
        ? '${widget.prefix ?? ''}••••••••'
        : '${widget.prefix ?? ''}${_formatBalance()}';
    _characterLayout = _BalanceCharacterLayout.from(_visibleText);
  }

  String _formatBalance() {
    final formatter = NumberFormat.decimalPattern(widget.locale)
      ..minimumFractionDigits = widget.decimalPlaces
      ..maximumFractionDigits = widget.decimalPlaces;
    return formatter.format(widget.balance);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHidden) {
      return _buildRow(widget.style);
    }

    if (!widget.enableFlash) {
      return _buildRow(widget.style);
    }

    return AnimatedBuilder(
      animation: _flashOpacity,
      builder: (context, _) {
        final alpha = _flashOpacity.value;
        final Color textColor = alpha > 0.01
            ? Color.lerp(
                widget.style.color ?? Theme.of(context).colorScheme.onPrimary,
                _flashColor,
                alpha,
              )!
            : (widget.style.color ?? Theme.of(context).colorScheme.onPrimary);
        return _buildRow(widget.style.copyWith(color: textColor));
      },
    );
  }

  Widget _buildRow(TextStyle style) {
    if (widget.isHidden) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _characterLayout.all
            .map((character) => _buildHiddenCharacter(character, style))
            .toList(growable: false),
      );
    }
    final leadingChars = _buildCharacters(_characterLayout.leading, style);
    final decimalChars = _buildCharacters(_characterLayout.decimal, style);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...leadingChars,
        if (decimalChars.isNotEmpty)
          GestureDetector(
            onTap: widget.onDecimalTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: decimalChars,
            ),
          ),
      ],
    );
  }

  Widget _buildHiddenCharacter(_BalanceCharacter character, TextStyle style) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.characterSpacing * 0.5),
      child: Text(
        character.value,
        style: style.copyWith(
          fontSize: (style.fontSize ?? 40) * 0.8,
          letterSpacing: 2,
        ),
      ),
    );
  }

  List<Widget> _buildCharacters(
    List<_BalanceCharacter> characters,
    TextStyle style,
  ) {
    return characters.map((character) {
      final currentStyle = character.isDecimalPart
          ? style.copyWith(
              fontSize: (style.fontSize ?? 40) * widget.decimalScaleFactor,
              color: style.color?.withValues(alpha: 0.8),
            )
          : style;

      late final Widget child;

      if (!character.isDigit) {
        child = Text(
          character.value,
          style: character.isSeparator
              ? style.copyWith(
                  fontSize:
                      (style.fontSize ?? 40) * widget.separatorScaleFactor,
                  color: style.color?.withValues(alpha: 0.5),
                )
              : currentStyle,
          key: ValueKey('static_${_layoutGeneration}_${character.index}'),
        );
      } else {
        final delay = widget.animateInitialValue && _allowRollOnThisUpdate
            ? KeroseneMotion.stagger(character.index)
            : Duration.zero;

        child = _RollingDigit(
          // Stable key by position so digit identity survives value changes.
          key: ValueKey('rolling_${_layoutGeneration}_${character.index}'),
          digit: character.value,
          style: currentStyle,
          delay: delay,
          widthFactor: widget.digitWidthFactor,
          animateInitialValue:
              widget.animateInitialValue && _allowRollOnThisUpdate,
          allowRollOnChange: _allowRollOnThisUpdate && !widget.suppressRoll,
        );
      }

      return Padding(
        padding:
            EdgeInsets.symmetric(horizontal: widget.characterSpacing * 0.5),
        child: child,
      );
    }).toList(growable: false);
  }
}

class _BalanceCharacterLayout {
  final List<_BalanceCharacter> leading;
  final List<_BalanceCharacter> decimal;

  const _BalanceCharacterLayout({
    required this.leading,
    required this.decimal,
  });

  List<_BalanceCharacter> get all => [...leading, ...decimal];

  factory _BalanceCharacterLayout.from(String text) {
    final separatorIndex = text.lastIndexOf(RegExp(r'[.,]'));
    final all = <_BalanceCharacter>[
      for (var i = 0; i < text.length; i++)
        _BalanceCharacter(
          index: i,
          value: text[i],
          separatorIndex: separatorIndex,
        ),
    ];
    if (separatorIndex < 0) {
      return _BalanceCharacterLayout(leading: all, decimal: const []);
    }
    return _BalanceCharacterLayout(
      leading: all.sublist(0, separatorIndex + 1),
      decimal: all.sublist(separatorIndex + 1),
    );
  }
}

class _BalanceCharacter {
  final int index;
  final String value;
  final int separatorIndex;

  const _BalanceCharacter({
    required this.index,
    required this.value,
    required this.separatorIndex,
  });

  bool get isDigit {
    final codeUnit = value.codeUnitAt(0);
    return codeUnit >= 48 && codeUnit <= 57;
  }

  bool get isDecimalPart => separatorIndex != -1 && index > separatorIndex;

  bool get isSeparator => value == '.' || value == ',';
}

class _RollingDigit extends StatefulWidget {
  final String digit;
  final TextStyle style;
  final Duration delay;
  final double widthFactor;
  final bool animateInitialValue;
  final bool allowRollOnChange;

  const _RollingDigit({
    super.key,
    required this.digit,
    required this.style,
    this.delay = Duration.zero,
    this.widthFactor = 0.64,
    this.animateInitialValue = false,
    this.allowRollOnChange = false,
  });

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit>
    with SingleTickerProviderStateMixin {
  static const double _visibleExtent = 1.35;
  static const double _edgeOpacity = 0.16;
  static const double _edgeScale = 0.82;
  static const double _maxTiltRadians = 0.55;
  static const double _perspective = 0.002;

  late AnimationController _controller;
  late Animation<double> _animation;
  late int _targetDigit;
  late int _previousDigit;
  int _rotations = 0;

  @override
  void initState() {
    super.initState();
    _targetDigit = int.tryParse(widget.digit) ?? 0;
    _previousDigit = _targetDigit;

    // Ceremony: short spin (not 3s). Updates: calm odometer.
    _controller = AnimationController(
      vsync: this,
      duration: widget.animateInitialValue
          ? KeroseneMotion.odometerCeremony
          : KeroseneMotion.odometerUpdate,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: KeroseneMotion.entrance,
    );

    if (widget.animateInitialValue) {
      Future.delayed(widget.delay, () {
        if (!mounted) return;
        setState(() {
          _rotations = 1;
          _previousDigit = (_targetDigit + 7) % 10;
        });
        _controller.forward(from: 0.0);
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDigit = int.tryParse(widget.digit) ?? 0;
    if (newDigit == _targetDigit) return;

    if (!widget.allowRollOnChange) {
      // Instant snap — e.g. ledger tab change or small delta.
      setState(() {
        _previousDigit = newDigit;
        _targetDigit = newDigit;
        _rotations = 0;
      });
      _controller.value = 1.0;
      return;
    }

    setState(() {
      _previousDigit = _targetDigit;
      _targetDigit = newDigit;
      _rotations = 0;
    });
    _controller.duration = KeroseneMotion.odometerUpdate;
    _controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double fontSize = widget.style.fontSize ?? 40;
    final double height = fontSize * 1.32;

    return SizedBox(
      height: height,
      width: fontSize * widget.widthFactor,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final t = _animation.value;
            if (t >= 0.999) {
              return _StaticDigit(
                digit: widget.digit,
                style: widget.style,
              );
            }

            int diff = _targetDigit - _previousDigit;
            if (diff < 0) diff += 10;

            final totalSteps = (_rotations * 10) + diff;
            if (totalSteps <= 0) {
              return _StaticDigit(digit: widget.digit, style: widget.style);
            }

            final baseColor =
                widget.style.color ?? Theme.of(context).colorScheme.onPrimary;
            final visibleDigits = <({double distance, Widget child})>[];

            for (int i = 0; i <= totalSteps; i++) {
              final rawOffset = (i - (t * totalSteps)) * height;
              final normalizedOffset = rawOffset / height;
              final distance = normalizedOffset.abs();

              if (distance > _visibleExtent) {
                continue;
              }

              final centerProgress =
                  (1 - (distance / _visibleExtent)).clamp(0.0, 1.0).toDouble();
              final easedCenter =
                  KeroseneMotion.standard.transform(centerProgress);
              final opacity = _edgeOpacity + ((1 - _edgeOpacity) * easedCenter);
              final scale = _edgeScale + ((1 - _edgeScale) * easedCenter);
              final tilt = normalizedOffset * _maxTiltRadians;
              final curvedOffset = math.sin(
                      (normalizedOffset / _visibleExtent) * (math.pi / 2)) *
                  height *
                  _visibleExtent;

              visibleDigits.add((
                distance: distance,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, _perspective)
                    ..translateByDouble(0.0, curvedOffset, 0.0, 1.0)
                    ..rotateX(tilt)
                    ..scaleByDouble(scale, scale, 1.0, 1.0),
                  child: Center(
                    child: Text(
                      ((_previousDigit + i) % 10).toString(),
                      style: widget.style.copyWith(
                        color: baseColor.withValues(
                          alpha: (baseColor.a * opacity).clamp(0.0, 1.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ));
            }

            visibleDigits.sort((a, b) => b.distance.compareTo(a.distance));

            // Edge fade comes from per-digit opacity/scale above — no ShaderMask
            // (dstIn forces saveLayer every roll frame).
            return RepaintBoundary(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final digit in visibleDigits) digit.child,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StaticDigit extends StatelessWidget {
  final String digit;
  final TextStyle style;

  const _StaticDigit({
    required this.digit,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(digit, style: style),
    );
  }
}
