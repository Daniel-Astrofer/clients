import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_colors.dart';
import 'package:kerosene/core/theme/app_spacing.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/design_system/icons.dart';

/// Professional amount-entry surface (send / receive).
///
/// Natural left-to-right decimal entry via embedded keypad (no system keyboard),
/// currency chip, conversion line, optional balance/fee/warning, and CTA.
class TransactionValueEntrySurface extends StatelessWidget {
  final VoidCallback onBack;
  final String? title;
  final String? subtitle;
  final String amountInput;
  final String unitLabel;
  final Currency currency;
  final String fiatReference;
  final Widget? configuration;
  final bool showKeypad;
  final ValueChanged<String>? onKeyTap;
  final VoidCallback? onCurrencyTap;
  final String? availableLabel;
  final String? feeLabel;
  final String? warningLabel;
  final List<({String label, String key})> quickActions;
  final ValueChanged<String>? onQuickAction;
  final String ctaLabel;
  final bool ctaEnabled;
  final bool isBusy;
  final VoidCallback onCta;

  const TransactionValueEntrySurface({
    super.key,
    required this.onBack,
    this.title,
    this.subtitle,
    this.amountInput = '0',
    this.unitLabel = '₿',
    this.currency = Currency.btc,
    required this.fiatReference,
    this.configuration,
    this.showKeypad = true,
    this.onKeyTap,
    this.onCurrencyTap,
    this.availableLabel,
    this.feeLabel,
    this.warningLabel,
    this.quickActions = const [],
    this.onQuickAction,
    required this.ctaLabel,
    required this.ctaEnabled,
    required this.isBusy,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final hasWarning = warningLabel != null && warningLabel!.trim().isNotEmpty;

    return ColoredBox(
      color: _C.bg,
      child: SafeArea(
        child: Column(
          children: [
            _Header(
              onBack: onBack,
              title: title,
              subtitle: subtitle,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 640;
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl2,
                      compact ? 8 : 16,
                      AppSpacing.xl2,
                      12,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 24,
                        maxWidth: context.responsive.appColumnMaxWidth,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CurrencyChip(
                            label: unitLabel,
                            currency: currency,
                            onTap: showKeypad ? onCurrencyTap : null,
                          ),
                          SizedBox(height: compact ? 18 : 28),
                          _AmountHero(
                            amountInput: amountInput,
                            currency: currency,
                            hasWarning: hasWarning,
                            showCursor: showKeypad,
                          ),
                          const SizedBox(height: 10),
                          _ConversionLine(
                            text: fiatReference,
                            onTap: showKeypad ? onCurrencyTap : null,
                          ),
                          if (availableLabel != null ||
                              feeLabel != null ||
                              hasWarning) ...[
                            const SizedBox(height: 22),
                            _ContextPanel(
                              availableLabel: availableLabel,
                              feeLabel: feeLabel,
                              warningLabel: warningLabel,
                            ),
                          ],
                          if (configuration != null) ...[
                            const SizedBox(height: 20),
                            configuration!,
                          ],
                          if (quickActions.isNotEmpty && showKeypad) ...[
                            const SizedBox(height: 18),
                            _QuickActions(
                              actions: quickActions,
                              onTap: onQuickAction,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (showKeypad && onKeyTap != null) _Keypad(onKeyTap: onKeyTap!),
            _CtaBar(
              label: ctaLabel,
              enabled: ctaEnabled,
              isBusy: isBusy,
              onCta: onCta,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final String? title;
  final String? subtitle;

  const _Header({
    required this.onBack,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(KeroseneIcons.back, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: _C.text,
              minimumSize: const Size.square(48),
            ),
          ),
          Expanded(
            child: hasTitle
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.inter(
                          color: _C.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.inter(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Currency chip
// ---------------------------------------------------------------------------

class _CurrencyChip extends StatelessWidget {
  final String label;
  final Currency currency;
  final VoidCallback? onTap;

  const _CurrencyChip({
    required this.label,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = switch (currency) {
      Currency.btc => 'Bitcoin',
      Currency.usd => 'US Dollar',
      Currency.eur => 'Euro',
      Currency.brl => 'Real',
    };

    // Flat text control — no gray pill background.
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.inter(
                color: _C.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: AppTypography.inter(
                color: _C.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                KeroseneIcons.chevronDown,
                size: 16,
                color: _C.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount hero
// ---------------------------------------------------------------------------

class _AmountHero extends StatefulWidget {
  final String amountInput;
  final Currency currency;
  final bool hasWarning;
  final bool showCursor;

  const _AmountHero({
    required this.amountInput,
    required this.currency,
    required this.hasWarning,
    required this.showCursor,
  });

  @override
  State<_AmountHero> createState() => _AmountHeroState();
}

class _AmountHeroState extends State<_AmountHero>
    with TickerProviderStateMixin {
  static const _pulseScale = 0.985;
  static const _digitIn = Duration(milliseconds: 160);
  static const _settle = Duration(milliseconds: 220);
  static const _shakeMs = Duration(milliseconds: 280);

  late final AnimationController _cursor;
  late final AnimationController _pulse;
  late final AnimationController _shake;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _shakeX;

  @override
  void initState() {
    super.initState();
    _cursor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = AnimationController(vsync: this, duration: _digitIn);
    _shake = AnimationController(vsync: this, duration: _shakeMs);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: _pulseScale)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: _pulseScale, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
    ]).animate(_pulse);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.72)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 65,
      ),
    ]).animate(_pulse);

    // Micro horizontal shake: 0 → 2 → -2 → 1 → 0 (logical px).
    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 2.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: -2.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOutCubic));

    if (widget.showCursor) {
      _cursor.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AmountHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showCursor && !_cursor.isAnimating) {
      _cursor.repeat(reverse: true);
    } else if (!widget.showCursor && _cursor.isAnimating) {
      _cursor.stop();
      _cursor.value = 0;
    }

    final amountChanged = oldWidget.amountInput != widget.amountInput;
    final currencyChanged = oldWidget.currency != widget.currency;
    if (amountChanged || currencyChanged) {
      final lengthDelta =
          (widget.amountInput.length - oldWidget.amountInput.length).abs();
      final settle = currencyChanged || lengthDelta > 2;
      _playPulse(settle: settle);
    }

    if (!oldWidget.hasWarning && widget.hasWarning) {
      _playShake();
    }
  }

  void _playPulse({required bool settle}) {
    if (!mounted) return;
    if (_reduceMotion(context)) return;
    _pulse.duration = settle ? _settle : _digitIn;
    _pulse.forward(from: 0);
  }

  void _playShake() {
    if (!mounted) return;
    if (_reduceMotion(context)) return;
    _shake.forward(from: 0);
  }

  bool _reduceMotion(BuildContext context) {
    return KeroseneMotion.reduceMotion(context);
  }

  @override
  void dispose() {
    _cursor.dispose();
    _pulse.dispose();
    _shake.dispose();
    super.dispose();
  }

  TextStyle _amountStyle(Color color) {
    return AppTypography.inter(
      color: color,
      fontSize: 56,
      fontWeight: FontWeight.w600,
      height: 1.05,
      letterSpacing: -1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Prefix + last grapheme so only the trailing digit pops in (PR2).
  ({String prefix, String tail}) _splitDisplay(String display) {
    if (display.isEmpty) return (prefix: '', tail: '');
    final chars = display.characters;
    if (chars.length <= 1) return (prefix: '', tail: display);
    return (
      prefix: chars.skipLast(1).toString(),
      tail: chars.last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = MoneyDisplay.formatEditableInput(
      rawValue: widget.amountInput,
      currency: widget.currency,
      withSymbol: false,
      appLocale: Localizations.localeOf(context),
    );
    final color = widget.hasWarning ? _C.warning : _C.text;
    final reduce = _reduceMotion(context);
    final style = _amountStyle(color);
    final parts = _splitDisplay(display);
    final digitDuration =
        KeroseneMotion.duration(context, const Duration(milliseconds: 150));

    Widget amountRow;
    if (reduce) {
      amountRow = Text(display, style: style);
    } else {
      amountRow = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (parts.prefix.isNotEmpty)
            Text(
              parts.prefix,
              style: style,
            ),
          AnimatedSwitcher(
            duration: digitDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  ...previous,
                  if (current != null) current,
                ],
              );
            },
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.12),
                end: Offset.zero,
              ).animate(fade);
              return FadeTransition(
                opacity: fade,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: Text(
              parts.tail,
              key: ValueKey<String>(
                '${widget.currency.name}-${parts.prefix}-${parts.tail}',
              ),
              style: style,
            ),
          ),
        ],
      );
    }

    Widget content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          amountRow,
          if (widget.showCursor) ...[
            const SizedBox(width: 2),
            FadeTransition(
              opacity: _cursor,
              child: Container(
                width: 2.5,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (reduce) {
      return Semantics(
        liveRegion: true,
        label: display,
        child: content,
      );
    }

    return Semantics(
      liveRegion: true,
      label: display,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _shake]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeX.value, 0),
              child: Transform.scale(
                scale: _scale.value,
                child: Opacity(
                  opacity: _opacity.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: content,
        ),
      ),
    );
  }
}

class _ConversionLine extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;

  const _ConversionLine({required this.text, this.onTap});

  @override
  State<_ConversionLine> createState() => _ConversionLineState();
}

class _ConversionLineState extends State<_ConversionLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swapSpin;

  @override
  void initState() {
    super.initState();
    _swapSpin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _swapSpin.dispose();
    super.dispose();
  }

  void _onTap() {
    if (widget.onTap == null) return;
    HapticFeedback.selectionClick();
    if (!KeroseneMotion.reduceMotion(context)) {
      _swapSpin.forward(from: 0);
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = KeroseneMotion.reduceMotion(context);
    final duration = KeroseneMotion.duration(
      context,
      const Duration(milliseconds: 220),
    );

    final label = Text(
      widget.text,
      key: ValueKey<String>(widget.text),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTypography.inter(
        color: _C.muted,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.25,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null ? null : _onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: reduce
                ? label
                : AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: label,
                  ),
          ),
          if (widget.onTap != null) ...[
            const SizedBox(width: 6),
            RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.5).animate(
                CurvedAnimation(
                  parent: _swapSpin,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: Icon(
                KeroseneIcons.swap,
                size: 14,
                color: _C.muted.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Context panel (balance / fee / warning)
// ---------------------------------------------------------------------------

class _ContextPanel extends StatelessWidget {
  final String? availableLabel;
  final String? feeLabel;
  final String? warningLabel;

  const _ContextPanel({
    this.availableLabel,
    this.feeLabel,
    this.warningLabel,
  });

  @override
  Widget build(BuildContext context) {
    // No gray panel — flat, centered meta lines under the amount.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (availableLabel != null)
          _ContextLine(
            label: _availableLabel(context),
            value: availableLabel!,
          ),
        if (availableLabel != null && feeLabel != null)
          const SizedBox(height: 8),
        if (feeLabel != null)
          _ContextLine(label: context.tr.sendReviewNetworkFee, value: feeLabel!),
        if (warningLabel != null && warningLabel!.trim().isNotEmpty) ...[
          if (availableLabel != null || feeLabel != null)
            const SizedBox(height: 10),
          Text(
            warningLabel!,
            textAlign: TextAlign.center,
            style: AppTypography.inter(
              color: _C.warning,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

String _availableLabel(BuildContext context) {
  return switch (Localizations.localeOf(context).languageCode) {
    'en' => 'Available',
    'es' => 'Disponible',
    _ => 'Disponível',
  };
}

class _ContextLine extends StatelessWidget {
  final String label;
  final String value;

  const _ContextLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: AppTypography.inter(
              color: _C.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(
            text: value,
            style: AppTypography.inter(
              color: _C.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _QuickActions extends StatelessWidget {
  final List<({String label, String key})> actions;
  final ValueChanged<String>? onTap;

  const _QuickActions({required this.actions, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final action in actions)
          Material(
            color: _C.chip,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onTap!(action.key);
                    },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  action.label,
                  style: AppTypography.inter(
                    color: _C.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Keypad
// ---------------------------------------------------------------------------

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;

  const _Keypad({required this.onKeyTap});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '←'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in _rows) ...[
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: _Key(
                      label: key,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onKeyTap(key);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _Key({required this.label, required this.onTap});

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> with SingleTickerProviderStateMixin {
  static const _pressScale = 0.96;
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: _pressScale).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Fire value change immediately; press animation runs in parallel.
    widget.onTap();
    if (!mounted || KeroseneMotion.reduceMotion(context)) return;
    _press.forward(from: 0).then((_) {
      if (mounted) _press.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBackspace = widget.label == '←';
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: ScaleTransition(
            scale: _scale,
            child: SizedBox(
              height: 56,
              child: Center(
                child: isBackspace
                    ? const Icon(
                        KeroseneIcons.backspace,
                        color: _C.text,
                        size: 22,
                      )
                    : Text(
                        widget.label,
                        style: AppTypography.inter(
                          color: _C.text,
                          fontSize: 26,
                          fontWeight: FontWeight.w400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA
// ---------------------------------------------------------------------------

String _softCtaLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  return '${lower[0].toUpperCase()}${lower.substring(1)}';
}

class _CtaBar extends StatefulWidget {
  final String label;
  final bool enabled;
  final bool isBusy;
  final VoidCallback onCta;

  const _CtaBar({
    required this.label,
    required this.enabled,
    required this.isBusy,
    required this.onCta,
  });

  @override
  State<_CtaBar> createState() => _CtaBarState();
}

class _CtaBarState extends State<_CtaBar> with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.isBusy) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _CtaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy && !oldWidget.isBusy) {
      _spinController.repeat();
    } else if (!widget.isBusy && oldWidget.isBusy) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: widget.enabled ? _C.bg : _C.muted,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: widget.isBusy ? 54 : maxWidth,
            height: 54,
            decoration: BoxDecoration(
              color: widget.enabled || widget.isBusy ? _C.text : _C.chip,
              borderRadius: BorderRadius.circular(widget.isBusy ? 27 : 16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(widget.isBusy ? 27 : 16),
                onTap: widget.enabled && !widget.isBusy ? widget.onCta : null,
                child: Center(
                  child: widget.isBusy
                      ? RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _spinController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _spinController.value * 2 * 3.141592653589793,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _C.bg.withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _C.bg,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : Text(
                          _softCtaLabel(widget.label),
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _C {
  const _C._();

  static const bg = AppColors.hexFF000000;
  static const text = AppColors.hexFFFFFFFF;
  static const muted = Color(0xFF8E8E93);
  static const chip = Color(0xFF1C1C1E);
  static const warning = Color(0xFFFFB020);
}
