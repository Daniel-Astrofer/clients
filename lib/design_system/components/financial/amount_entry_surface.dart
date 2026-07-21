import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_colors.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';

/// Professional amount-entry surface (send / receive).
///
/// Supports either an embedded keypad or the device system keyboard
/// ([useSystemKeyboard]), plus currency chip, conversion line, optional
/// balance/fee/warning, and CTA.
///
/// Lives in the design system so send / receive / movement share one chrome.
class TransactionValueEntrySurface extends StatelessWidget {
  final VoidCallback onBack;
  final String? title;
  final String? subtitle;
  final TextStyle? titleStyle;
  /// When true, back + [title] share one top row; amount stays vertically centered.
  final bool inlineHeroTitle;
  /// Top inset for the inline title row (receive flow alignment).
  final double? titleTopInset;
  /// Viewport fraction from top for overlay H1 (receive flow).
  final double? titleViewportFraction;
  /// When set, renders [title] as a hero below the header at this fraction of
  /// the viewport height from the top (e.g. 0.30 = 30% down).
  final double? titleTopInsetFraction;
  final String amountInput;
  final String unitLabel;
  final Currency currency;
  final String fiatReference;
  final Widget? configuration;
  final bool showKeypad;
  /// When true, uses the OS number keyboard instead of the embedded keypad.
  final bool useSystemKeyboard;
  final ValueChanged<String>? onKeyTap;
  final ValueChanged<String>? onAmountTextChanged;
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
    this.titleStyle,
    this.inlineHeroTitle = false,
    this.titleTopInset,
    this.titleViewportFraction,
    this.titleTopInsetFraction,
    this.amountInput = '0',
    this.unitLabel = '₿',
    this.currency = Currency.btc,
    required this.fiatReference,
    this.configuration,
    this.showKeypad = true,
    this.useSystemKeyboard = false,
    this.onKeyTap,
    this.onAmountTextChanged,
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
    final editable = useSystemKeyboard && onAmountTextChanged != null;
    final keypadVisible = !editable && showKeypad && onKeyTap != null;
    final currencyTapEnabled = editable || showKeypad;
    final heroTitle = !inlineHeroTitle &&
        titleTopInsetFraction != null &&
        title != null &&
        title!.trim().isNotEmpty;
    final inlineTitle = inlineHeroTitle &&
        title != null &&
        title!.trim().isNotEmpty;
    final headerTitle = heroTitle || inlineTitle ? null : title;

    return ColoredBox(
      color: _C.bg,
      child: SafeArea(
        child: inlineTitle
            ? _InlineHeroLayout(
                onBack: onBack,
                title: title!,
                titleStyle: titleStyle,
                titleTopInset: titleTopInset,
                titleViewportFraction: titleViewportFraction,
                amountInput: amountInput,
                unitLabel: unitLabel,
                currency: currency,
                fiatReference: fiatReference,
                configuration: configuration,
                editable: editable,
                hasWarning: hasWarning,
                onAmountTextChanged: onAmountTextChanged,
                onCurrencyTap: onCurrencyTap,
                currencyTapEnabled: currencyTapEnabled,
                showKeypad: showKeypad,
                availableLabel: availableLabel,
                feeLabel: feeLabel,
                warningLabel: warningLabel,
                quickActions: quickActions,
                onQuickAction: onQuickAction,
                keypadVisible: keypadVisible,
                onKeyTap: onKeyTap,
                ctaLabel: ctaLabel,
                ctaEnabled: ctaEnabled,
                isBusy: isBusy,
                onCta: onCta,
              )
            : Column(
                children: [
                  _Header(
                    onBack: onBack,
                    title: headerTitle,
                    subtitle: subtitle,
                  ),
            if (heroTitle)
              SizedBox(
                height: MediaQuery.sizeOf(context).height * titleTopInsetFraction!,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl2, 0, AppSpacing.xl2, 8),
                    child: Text(
                      title!,
                      style: titleStyle ?? AppTypography.h1,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 640;
                  final content = Padding(
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
                            onTap: currencyTapEnabled ? onCurrencyTap : null,
                          ),
                          SizedBox(height: compact ? 18 : 28),
                          if (editable)
                            _NativeAmountField(
                              amountInput: amountInput,
                              currency: currency,
                              hasWarning: hasWarning,
                              onChanged: onAmountTextChanged!,
                            )
                          else
                            _AmountHero(
                              amountInput: amountInput,
                              currency: currency,
                              hasWarning: hasWarning,
                              showCursor: showKeypad,
                            ),
                          const SizedBox(height: 10),
                          _ConversionLine(
                            text: fiatReference,
                            onTap: currencyTapEnabled ? onCurrencyTap : null,
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
                            SizedBox(height: compact ? 8 : 20),
                            configuration!,
                          ],
                          if (quickActions.isNotEmpty &&
                              (keypadVisible || editable)) ...[
                            SizedBox(height: compact ? 8 : 18),
                            _QuickActions(
                              actions: quickActions,
                              onTap: onQuickAction,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );

                  // FittedBox breaks TextField focus/hit-testing — skip when
                  // using the system keyboard.
                  if (editable) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: content,
                    );
                  }

                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: content,
                  );
                },
              ),
            ),
            if (keypadVisible)
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = MediaQuery.sizeOf(context).height < 640;
                  return _Keypad(onKeyTap: onKeyTap!, compact: compact);
                },
              ),
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

/// Receive amount: title overlays the top; value stays viewport-centered.
class _InlineHeroLayout extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final TextStyle? titleStyle;
  final double? titleTopInset;
  final double? titleViewportFraction;
  final String amountInput;
  final String unitLabel;
  final Currency currency;
  final String fiatReference;
  final Widget? configuration;
  final bool editable;
  final bool hasWarning;
  final ValueChanged<String>? onAmountTextChanged;
  final VoidCallback? onCurrencyTap;
  final bool currencyTapEnabled;
  final bool showKeypad;
  final String? availableLabel;
  final String? feeLabel;
  final String? warningLabel;
  final List<({String label, String key})> quickActions;
  final ValueChanged<String>? onQuickAction;
  final bool keypadVisible;
  final ValueChanged<String>? onKeyTap;
  final String ctaLabel;
  final bool ctaEnabled;
  final bool isBusy;
  final VoidCallback onCta;

  const _InlineHeroLayout({
    required this.onBack,
    required this.title,
    this.titleStyle,
    this.titleTopInset,
    this.titleViewportFraction,
    required this.amountInput,
    required this.unitLabel,
    required this.currency,
    required this.fiatReference,
    this.configuration,
    required this.editable,
    required this.hasWarning,
    this.onAmountTextChanged,
    this.onCurrencyTap,
    required this.currencyTapEnabled,
    required this.showKeypad,
    this.availableLabel,
    this.feeLabel,
    this.warningLabel,
    this.quickActions = const [],
    this.onQuickAction,
    required this.keypadVisible,
    this.onKeyTap,
    required this.ctaLabel,
    required this.ctaEnabled,
    required this.isBusy,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 640;
    final titleTop = titleViewportFraction != null
        ? MediaQuery.paddingOf(context).top +
            MediaQuery.sizeOf(context).height * titleViewportFraction!
        : (titleTopInset ?? 8).toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.responsive.appColumnMaxWidth,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CurrencyChip(
                      label: unitLabel,
                      currency: currency,
                      onTap: currencyTapEnabled ? onCurrencyTap : null,
                    ),
                    SizedBox(height: compact ? 18 : 28),
                    if (editable)
                      _NativeAmountField(
                        amountInput: amountInput,
                        currency: currency,
                        hasWarning: hasWarning,
                        onChanged: onAmountTextChanged!,
                      )
                    else
                      _AmountHero(
                        amountInput: amountInput,
                        currency: currency,
                        hasWarning: hasWarning,
                        showCursor: showKeypad,
                      ),
                    const SizedBox(height: 10),
                    _ConversionLine(
                      text: fiatReference,
                      onTap: currencyTapEnabled ? onCurrencyTap : null,
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
                      SizedBox(height: compact ? 8 : 20),
                      configuration!,
                    ],
                    if (quickActions.isNotEmpty &&
                        (keypadVisible || editable)) ...[
                      SizedBox(height: compact ? 8 : 18),
                      _QuickActions(
                        actions: quickActions,
                        onTap: onQuickAction,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: titleTop,
          left: 0,
          right: 0,
          child: _InlineTitleHeader(
            onBack: onBack,
            title: title,
            titleStyle: titleStyle,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (keypadVisible)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final keypadCompact =
                        MediaQuery.sizeOf(context).height < 640;
                    return _Keypad(onKeyTap: onKeyTap!, compact: keypadCompact);
                  },
                ),
              _CtaBar(
                label: ctaLabel,
                enabled: ctaEnabled,
                isBusy: isBusy,
                onCta: onCta,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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

class _InlineTitleHeader extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final TextStyle? titleStyle;

  const _InlineTitleHeader({
    required this.onBack,
    required this.title,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, AppSpacing.xl2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(KeroseneIcons.back, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: _C.text,
              minimumSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                title,
                style: titleStyle ?? AppTypography.h1.copyWith(color: _C.text),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
// Amount hero (system keyboard)
// ---------------------------------------------------------------------------

class _NativeAmountField extends StatefulWidget {
  final String amountInput;
  final Currency currency;
  final bool hasWarning;
  final ValueChanged<String> onChanged;

  const _NativeAmountField({
    required this.amountInput,
    required this.currency,
    required this.hasWarning,
    required this.onChanged,
  });

  @override
  State<_NativeAmountField> createState() => _NativeAmountFieldState();
}

class _NativeAmountFieldState extends State<_NativeAmountField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _rawOrZero(widget.amountInput));
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant _NativeAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amountInput != widget.amountInput ||
        oldWidget.currency != widget.currency) {
      final next = _rawOrZero(widget.amountInput);
      if (_controller.text != next) {
        _syncing = true;
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        _syncing = false;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _rawOrZero(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? '0' : trimmed;
  }

  void _onChanged(String value) {
    if (_syncing) return;
    final maxLength = widget.currency == Currency.btc ? 16 : 14;
    final sanitized = MoneyDisplay.sanitizeEditableInput(
      rawValue: value,
      currency: widget.currency,
      maxLength: maxLength,
    );
    if (_controller.text != sanitized) {
      final selection = sanitized.length;
      _syncing = true;
      _controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: selection),
      );
      _syncing = false;
    }
    widget.onChanged(sanitized);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.hasWarning ? _C.warning : _C.text;
    // Match classic amount entry (Inter tabular), not mono financial.
    final style = AppTypography.amountLarge.copyWith(
      color: color,
      fontSize: 56,
      height: 1.05,
      letterSpacing: -1.2,
    );

    return TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      textInputAction: TextInputAction.done,
      style: style,
      cursorColor: color,
      cursorWidth: 2.5,
      decoration: const InputDecoration(
        filled: false,
        fillColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: _onChanged,
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
    return AppTypography.amountLarge.copyWith(
      color: color,
      fontSize: 56,
      height: 1.05,
      letterSpacing: -1.2,
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
  final bool compact;

  const _Keypad({required this.onKeyTap, this.compact = false});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '←'],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 0 : 4, 20, compact ? 0 : 8),
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
                      compact: compact,
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
  final bool compact;

  const _Key({required this.label, required this.onTap, this.compact = false});

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
              height: widget.compact ? 44 : 56,
              child: Center(
                child: isBackspace
                    ? Icon(
                        KeroseneIcons.backspace,
                        color: _C.text,
                        size: widget.compact ? 20 : 22,
                      )
                    : Text(
                        widget.label,
                        style: AppTypography.inter(
                          color: _C.text,
                          fontSize: widget.compact ? 22 : 26,
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl2,
        AppSpacing.xs,
        AppSpacing.xl2,
        AppSpacing.base,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: widget.isBusy ? 54 : maxWidth,
            height: AppSpacing.xxxl > AppSpacing.minTouch
                ? 54
                : AppSpacing.minTouch,
            decoration: BoxDecoration(
              color: widget.enabled || widget.isBusy ? _C.text : _C.chip,
              borderRadius: BorderRadius.circular(
                widget.isBusy ? 27 : 999,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  widget.isBusy ? 27 : 999,
                ),
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
