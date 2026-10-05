// architecture-allow-large-file: financial input state and rendering are kept
// together to preserve the public surface API and keyboard behavior.
import 'dart:async';
import 'dart:ui' show FontFeature, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/design_system/foundation/theme/app_spacing.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';

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
  final TextStyle? subtitleStyle;

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

  /// Optional bar above the CTA (e.g. calculator ops); sits above the keyboard
  /// when [Scaffold.resizeToAvoidBottomInset] is true.
  final Widget? bottomAccessory;

  /// When true with [inlineHeroTitle], title is horizontally centered; back
  /// arrow stays left and shares the title's vertical alignment.
  final bool centerInlineTitle;

  /// Shows currency symbol beside the editable amount (hides the top chip).
  final bool showCurrencyPrefix;

  /// Hides the top currency chip (independent of [showCurrencyPrefix]).
  final bool showCurrencyChip;

  /// Soft calculator expression above the amount (e.g. `100 +`).
  final String? expressionLabel;

  /// Triggers a short count-up morph when the amount resolves (`=`).
  final bool resolveAmount;

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
    this.subtitleStyle,
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
    this.bottomAccessory,
    this.centerInlineTitle = false,
    this.showCurrencyPrefix = false,
    this.showCurrencyChip = true,
    this.expressionLabel,
    this.resolveAmount = false,
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
    final heroTitle =
        !inlineHeroTitle &&
        titleTopInsetFraction != null &&
        title != null &&
        title!.trim().isNotEmpty;
    final inlineTitle =
        inlineHeroTitle && title != null && title!.trim().isNotEmpty;
    final headerTitle = heroTitle || inlineTitle ? null : title;

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return ColoredBox(
      color: _C.bg,
      child: SafeArea(
        // Avoid double bottom inset with the OS keyboard (causes overflow).
        bottom: !keyboardOpen,
        child: inlineTitle
            ? _InlineHeroLayout(
                onBack: onBack,
                title: title!,
                subtitle: subtitle,
                titleStyle: titleStyle,
                subtitleStyle: subtitleStyle,
                titleTopInset: titleTopInset,
                titleViewportFraction: titleViewportFraction,
                centerInlineTitle: centerInlineTitle,
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
                showCurrencyChip: showCurrencyChip && !showCurrencyPrefix,
                showCurrencyPrefix: showCurrencyPrefix,
                expressionLabel: expressionLabel,
                resolveAmount: resolveAmount,
                availableLabel: availableLabel,
                feeLabel: feeLabel,
                warningLabel: warningLabel,
                quickActions: quickActions,
                onQuickAction: onQuickAction,
                keypadVisible: keypadVisible,
                onKeyTap: onKeyTap,
                bottomAccessory: bottomAccessory,
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
                      height:
                          MediaQuery.sizeOf(context).height *
                          titleTopInsetFraction!,
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl2,
                            0,
                            AppSpacing.xl2,
                            8,
                          ),
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
                        final showChip =
                            showCurrencyChip && !showCurrencyPrefix;
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
                                if (showChip)
                                  _CurrencyChip(
                                    label: unitLabel,
                                    currency: currency,
                                    onTap: currencyTapEnabled
                                        ? onCurrencyTap
                                        : null,
                                  ),
                                if (showChip)
                                  SizedBox(height: compact ? 18 : 28),
                                if (editable)
                                  _NativeAmountField(
                                    amountInput: amountInput,
                                    currency: currency,
                                    hasWarning: hasWarning,
                                    showCurrencyPrefix: showCurrencyPrefix,
                                    expressionLabel: expressionLabel,
                                    resolveAmount: resolveAmount,
                                    onChanged: onAmountTextChanged!,
                                  )
                                else
                                  _AmountHero(
                                    amountInput: amountInput,
                                    currency: currency,
                                    hasWarning: hasWarning,
                                    showCursor: showKeypad,
                                    showCurrencyPrefix: showCurrencyPrefix,
                                  ),
                                const SizedBox(height: 10),
                                _ConversionLine(
                                  text: fiatReference,
                                  onTap: currencyTapEnabled
                                      ? onCurrencyTap
                                      : null,
                                ),
                                if (quickActions.isNotEmpty &&
                                    (keypadVisible || editable)) ...[
                                  SizedBox(height: compact ? 10 : 14),
                                  _QuickActions(
                                    actions: quickActions,
                                    onTap: onQuickAction,
                                  ),
                                ],
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
                  if (bottomAccessory != null) bottomAccessory!,
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
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final double? titleTopInset;
  final double? titleViewportFraction;
  final bool centerInlineTitle;
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
  final bool showCurrencyChip;
  final bool showCurrencyPrefix;
  final String? expressionLabel;
  final bool resolveAmount;
  final String? availableLabel;
  final String? feeLabel;
  final String? warningLabel;
  final List<({String label, String key})> quickActions;
  final ValueChanged<String>? onQuickAction;
  final bool keypadVisible;
  final ValueChanged<String>? onKeyTap;
  final Widget? bottomAccessory;
  final String ctaLabel;
  final bool ctaEnabled;
  final bool isBusy;
  final VoidCallback onCta;

  const _InlineHeroLayout({
    required this.onBack,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.titleTopInset,
    this.titleViewportFraction,
    this.centerInlineTitle = false,
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
    this.showCurrencyChip = true,
    this.showCurrencyPrefix = false,
    this.expressionLabel,
    this.resolveAmount = false,
    this.availableLabel,
    this.feeLabel,
    this.warningLabel,
    this.quickActions = const [],
    this.onQuickAction,
    required this.keypadVisible,
    this.onKeyTap,
    this.bottomAccessory,
    required this.ctaLabel,
    required this.ctaEnabled,
    required this.isBusy,
    required this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 640;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 40;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        MediaQuery.paddingOf(context).top;
    final tight = availableHeight < 520;
    final showAccessory = bottomAccessory != null;

    final amountBlock = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCurrencyChip) ...[
          Center(
            child: _CurrencyChip(
              label: unitLabel,
              currency: currency,
              onTap: currencyTapEnabled ? onCurrencyTap : null,
            ),
          ),
          SizedBox(height: keyboardOpen || tight ? 10 : 24),
        ],
        Center(
          child: editable
              ? SizedBox(
                  width: double.infinity,
                  child: _NativeAmountField(
                    amountInput: amountInput,
                    currency: currency,
                    hasWarning: hasWarning,
                    showCurrencyPrefix: showCurrencyPrefix,
                    expressionLabel: expressionLabel,
                    resolveAmount: resolveAmount,
                    onChanged: onAmountTextChanged!,
                  ),
                )
              : _AmountHero(
                  amountInput: amountInput,
                  currency: currency,
                  hasWarning: hasWarning,
                  showCursor: showKeypad,
                  showCurrencyPrefix: showCurrencyPrefix,
                ),
        ),
        SizedBox(height: keyboardOpen || tight ? 6 : 10),
        Center(
          child: _ConversionLine(
            text: fiatReference,
            onTap: currencyTapEnabled ? onCurrencyTap : null,
          ),
        ),
        if (quickActions.isNotEmpty && (keypadVisible || editable)) ...[
          SizedBox(height: compact ? 10 : 14),
          _QuickActions(actions: quickActions, onTap: onQuickAction),
        ],
        if (availableLabel != null || feeLabel != null || hasWarning) ...[
          const SizedBox(height: 16),
          _ContextPanel(
            availableLabel: availableLabel,
            feeLabel: feeLabel,
            warningLabel: warningLabel,
          ),
        ],
        if (configuration != null) ...[
          SizedBox(height: keyboardOpen || tight ? 10 : 16),
          configuration!,
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InlineTitleHeader(
          onBack: onBack,
          title: title,
          subtitle: subtitle,
          titleStyle: titleStyle,
          subtitleStyle: subtitleStyle,
          centerTitle: centerInlineTitle,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minBody = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : 0.0;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl2,
                  keyboardOpen || tight ? 8 : 16,
                  AppSpacing.xl2,
                  keyboardOpen || tight ? 8 : 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (minBody - (keyboardOpen || tight ? 16 : 32))
                        .clamp(0.0, double.infinity),
                    maxWidth: context.responsive.appColumnMaxWidth,
                  ),
                  child: Center(child: amountBlock),
                ),
              );
            },
          ),
        ),
        if (keypadVisible)
          _Keypad(onKeyTap: onKeyTap!, compact: compact || tight),
        if (showAccessory) bottomAccessory!,
        _CtaBar(
          label: ctaLabel,
          enabled: ctaEnabled,
          isBusy: isBusy,
          onCta: onCta,
          compact: keyboardOpen || tight,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final String? title;
  final String? subtitle;

  const _Header({required this.onBack, this.title, this.subtitle});

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
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final bool centerTitle;

  const _InlineTitleHeader({
    required this.onBack,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = titleStyle ?? AppTypography.h1.copyWith(color: _C.text);
    final subStyle =
        subtitleStyle ??
        AppTypography.inter(
          color: _C.muted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        );
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    final back = _BackArrowButton(onPressed: onBack);

    Widget titleBlock({required TextAlign align}) {
      return AnimatedSwitcher(
        duration: KeroseneMotion.duration(context, KeroseneMotion.inputTitle),
        switchInCurve: KeroseneMotion.standard,
        switchOutCurve: KeroseneMotion.exit,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Column(
          key: ValueKey<String>('$title|${subtitle ?? ''}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: align == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: style,
              textAlign: align,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasSubtitle) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!.trim(),
                style: subStyle,
                textAlign: align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }

    if (!centerTitle) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, AppSpacing.xl2, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            back,
            Expanded(child: titleBlock(align: TextAlign.start)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: SizedBox(
        height: hasSubtitle ? 58 : 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: titleBlock(align: TextAlign.center),
            ),
            Align(alignment: Alignment.centerLeft, child: back),
          ],
        ),
      ),
    );
  }
}

/// Back chevron with press scale; single tap path (no double handlers).
class _BackArrowButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _BackArrowButton({required this.onPressed});

  @override
  State<_BackArrowButton> createState() => _BackArrowButtonState();
}

class _BackArrowButtonState extends State<_BackArrowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: KeroseneMotion.inputPress,
      reverseDuration: KeroseneMotion.inputPressReverse,
    );
    _scale = Tween<double>(begin: 1, end: 0.9).animate(
      CurvedAnimation(
        parent: _press,
        curve: KeroseneMotion.exit,
        reverseCurve: KeroseneMotion.standard,
      ),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!KeroseneMotion.reduceMotion(context)) {
      await _press.forward(from: 0);
      if (mounted) await _press.reverse();
    }
    if (!mounted) return;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: _handleTap,
        icon: const Icon(KeroseneIcons.back, size: 22),
        style: IconButton.styleFrom(
          foregroundColor: _C.text,
          minimumSize: const Size.square(48),
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
        ),
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
              Icon(KeroseneIcons.chevronDown, size: 16, color: _C.muted),
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
  final bool showCurrencyPrefix;
  final String? expressionLabel;
  final bool resolveAmount;
  final ValueChanged<String> onChanged;

  const _NativeAmountField({
    required this.amountInput,
    required this.currency,
    required this.hasWarning,
    this.showCurrencyPrefix = false,
    this.expressionLabel,
    this.resolveAmount = false,
    required this.onChanged,
  });

  @override
  State<_NativeAmountField> createState() => _NativeAmountFieldState();
}

class _NativeAmountFieldState extends State<_NativeAmountField>
    with TickerProviderStateMixin {
  static const _expressionSpring = SpringDescription(
    mass: 1.0,
    stiffness: 220,
    damping: 18,
  );

  late final TextEditingController _controller;
  late final FocusNode _focus;
  late final AnimationController _countUp;
  late final AnimationController _expression;

  bool _syncing = false;

  /// Last value we pushed upstream — avoids fighting the TextField/IME.
  String _lastEmitted = '0';
  double _countFrom = 0;
  double _countTo = 0;
  bool _counting = false;

  /// Stable glyph identities — remount only when a digit is born.
  final List<_AmountGlyph> _glyphs = <_AmountGlyph>[];
  int _nextGlyphId = 0;

  @override
  void initState() {
    super.initState();
    final initial = _rawOrZero(widget.amountInput);
    _lastEmitted = initial;
    _controller = TextEditingController(text: initial);
    _focus = FocusNode();
    _expression = AnimationController.unbounded(vsync: this)..value = 0;
    _countUp = AnimationController(
      vsync: this,
      duration: KeroseneMotion.inputCountUp,
    );
    _countUp.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _counting = false);
      }
    });
    final hasExpr = (widget.expressionLabel ?? '').trim().isNotEmpty;
    _expression.value = hasExpr ? 1 : 0;
    _syncGlyphs(
      MoneyDisplay.formatEditableInput(
        rawValue: initial,
        currency: widget.currency,
        withSymbol: false,
      ),
      animate: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  @override
  void didUpdateWidget(covariant _NativeAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldExpr = (oldWidget.expressionLabel ?? '').trim();
    final newExpr = (widget.expressionLabel ?? '').trim();
    if (oldExpr != newExpr) {
      _expression.animateWith(
        SpringSimulation(
          _expressionSpring,
          _expression.value,
          newExpr.isEmpty ? 0.0 : 1.0,
          newExpr.isEmpty ? -1.0 : 1.5,
        ),
      );
    }

    if (oldWidget.amountInput != widget.amountInput ||
        oldWidget.currency != widget.currency) {
      final next = _rawOrZero(widget.amountInput);
      // Ignore echo of our own emit — never clobber the TextField mid-typing.
      if (next == _lastEmitted && oldWidget.currency == widget.currency) {
        return;
      }
      if (_controller.text == next && oldWidget.currency == widget.currency) {
        _lastEmitted = next;
        return;
      }

      final grew = next.length > _controller.text.length;
      if (widget.resolveAmount && !oldWidget.resolveAmount) {
        _countFrom = MoneyDisplay.parseEditableInput(oldWidget.amountInput);
        _countTo = MoneyDisplay.parseEditableInput(next);
        _counting = true;
        _countUp.forward(from: 0);
      } else if (grew && !_counting && !KeroseneMotion.reduceMotion(context)) {
        HapticFeedback.selectionClick();
      }
      _syncing = true;
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      _syncing = false;
      _lastEmitted = next;
      _syncGlyphs(
        MoneyDisplay.formatEditableInput(
          rawValue: next,
          currency: widget.currency,
          withSymbol: false,
          appLocale: Localizations.localeOf(context),
        ),
        animate: !_counting && oldWidget.currency == widget.currency,
      );
      setState(() {});
    }
  }

  static bool _isAmountSep(String char) {
    if (char.isEmpty) return false;
    final c = char.characters.first;
    // Decimal / grouping separators across locales (., ‚ ' thin space, etc.).
    return c == '.' ||
        c == ',' ||
        c == ' ' ||
        c == '\u00A0' ||
        c == '\u202F' ||
        c == '\u2009' ||
        c == "'" ||
        c == '’';
  }

  void _syncGlyphs(String display, {required bool animate}) {
    final chars = display.characters.toList(growable: false);
    if (chars.isEmpty) {
      _glyphs
        ..clear()
        ..add(
          _AmountGlyph(
            id: _nextGlyphId++,
            char: '0',
            enter: false,
            expandWidth: false,
            exiting: false,
          ),
        );
      return;
    }

    if (!animate) {
      _glyphs
        ..clear()
        ..addAll([
          for (final c in chars)
            _AmountGlyph(
              id: _nextGlyphId++,
              char: c,
              enter: false,
              expandWidth: false,
              exiting: false,
            ),
        ]);
      return;
    }

    final active = _glyphs.where((g) => !g.exiting).toList(growable: false);
    final activeStr = active.map((g) => g.char).join();
    final nextStr = chars.join();
    if (nextStr == activeStr) return;

    final prevDigits = active
        .where((g) => !_isAmountSep(g.char))
        .toList(growable: false);
    final prevSeps = active
        .where((g) => _isAmountSep(g.char))
        .toList(growable: false);
    final nextDigitChars = chars
        .where((c) => !_isAmountSep(c))
        .toList(growable: false);
    final nextSepCount = chars.length - nextDigitChars.length;

    final sharedDigits = prevDigits.length < nextDigitChars.length
        ? prevDigits.length
        : nextDigitChars.length;
    final insertedDigits = nextDigitChars.length - sharedDigits;
    final removedDigits = prevDigits.length - sharedDigits;

    final nextDigitGlyphs = <_AmountGlyph>[];
    final exitingFront = <_AmountGlyph>[];

    for (var i = 0; i < insertedDigits; i++) {
      nextDigitGlyphs.add(
        _AmountGlyph(
          id: _nextGlyphId++,
          char: nextDigitChars[i],
          enter: true,
          expandWidth: true,
          exiting: false,
        ),
      );
    }

    for (var i = 0; i < sharedDigits; i++) {
      final prev = prevDigits[prevDigits.length - sharedDigits + i];
      nextDigitGlyphs.add(
        _AmountGlyph(
          id: prev.id,
          char: nextDigitChars[insertedDigits + i],
          enter: false,
          expandWidth: false,
          exiting: false,
        ),
      );
    }

    for (var i = 0; i < removedDigits; i++) {
      final prev = prevDigits[i];
      exitingFront.add(
        _AmountGlyph(
          id: prev.id,
          char: prev.char,
          enter: false,
          expandWidth: true,
          exiting: true,
        ),
      );
    }

    final nextSepGlyphs = <_AmountGlyph>[];
    for (var i = 0; i < nextSepCount; i++) {
      if (i < prevSeps.length) {
        nextSepGlyphs.add(
          _AmountGlyph(
            id: prevSeps[i].id,
            char: chars
                .where((c) => _isAmountSep(c))
                .toList(growable: false)[i],
            enter: false,
            expandWidth: false,
            exiting: false,
          ),
        );
      } else {
        nextSepGlyphs.add(
          _AmountGlyph(
            id: _nextGlyphId++,
            char: chars
                .where((c) => _isAmountSep(c))
                .toList(growable: false)[i],
            enter: true,
            expandWidth: true,
            exiting: false,
          ),
        );
      }
    }

    final exitingSeps = <_AmountGlyph>[];
    for (var i = nextSepCount; i < prevSeps.length; i++) {
      final prev = prevSeps[i];
      exitingSeps.add(
        _AmountGlyph(
          id: prev.id,
          char: prev.char,
          enter: false,
          expandWidth: true,
          exiting: true,
        ),
      );
    }

    final rebuilt = <_AmountGlyph>[...exitingFront, ...exitingSeps];
    var digitIndex = 0;
    var sepIndex = 0;
    for (final c in chars) {
      if (_isAmountSep(c)) {
        rebuilt.add(nextSepGlyphs[sepIndex++]);
      } else {
        rebuilt.add(nextDigitGlyphs[digitIndex++]);
      }
    }

    _glyphs
      ..clear()
      ..addAll(rebuilt);
  }

  void _onGlyphExitComplete(int id) {
    if (!mounted) return;
    final idx = _glyphs.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    setState(() => _glyphs.removeAt(idx));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _countUp.dispose();
    _expression.dispose();
    super.dispose();
  }

  String _rawOrZero(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? '0' : trimmed;
  }

  String _displayFor(String raw) {
    return MoneyDisplay.formatEditableInput(
      rawValue: raw,
      currency: widget.currency,
      withSymbol: false,
      appLocale: Localizations.localeOf(context),
    );
  }

  void _onChanged(String value) {
    if (_syncing) return;
    final maxLength = widget.currency == Currency.btc ? 16 : 14;
    final sanitized = MoneyDisplay.sanitizeEditableInput(
      rawValue: value,
      currency: widget.currency,
      maxLength: maxLength,
    );
    final previous = _lastEmitted;
    final changed = sanitized != previous;

    // Only rewrite when sanitize mutates the raw IME string.
    if (sanitized != value) {
      _syncing = true;
      _controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
        composing: TextRange.empty,
      );
      _syncing = false;
    }

    if (!changed) return;

    final nextDisplay = _displayFor(sanitized);
    final prevDisplay = _displayFor(previous);
    final lenDelta =
        nextDisplay.characters.length - prevDisplay.characters.length;

    _lastEmitted = sanitized;
    if (lenDelta != 0 && !KeroseneMotion.reduceMotion(context)) {
      HapticFeedback.selectionClick();
    }

    _syncGlyphs(nextDisplay, animate: !KeroseneMotion.reduceMotion(context));
    widget.onChanged(sanitized);
    setState(() {});
  }

  TextStyle _amountStyle(Color color, {required double fontSize}) {
    return AppTypography.amountLarge.copyWith(
      color: color,
      fontSize: fontSize,
      height: 1.05,
      letterSpacing: -1.4,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  String _formatCount(double value) {
    final maxDecimals = widget.currency == Currency.btc ? 8 : 2;
    var text = value.toStringAsFixed(maxDecimals);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    if (text.isEmpty || text == '-') text = '0';
    return MoneyDisplay.formatEditableInput(
      rawValue: text,
      currency: widget.currency,
      withSymbol: false,
      appLocale: Localizations.localeOf(context),
    );
  }

  static const _bareInputDecoration = InputDecoration(
    isDense: true,
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    contentPadding: EdgeInsets.zero,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
  );

  @override
  Widget build(BuildContext context) {
    final color = widget.hasWarning ? _C.warning : _C.text;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 40;
    final baseSize = keyboardOpen ? 40.0 : 56.0;
    final symbol = MoneyDisplay.tickerSymbolFor(widget.currency);
    final reduce = KeroseneMotion.reduceMotion(context);
    final expression = widget.expressionLabel?.trim() ?? '';
    final hasExpression = expression.isNotEmpty;
    final style = _amountStyle(color, fontSize: baseSize);
    final symbolStyle = style.copyWith(
      color: _C.muted,
      fontSize: baseSize * 0.72,
      fontWeight: widget.currency == Currency.btc
          ? FontWeight.w300
          : style.fontWeight,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_countUp, _expression]),
      builder: (context, _) {
        final display = _counting
            ? _formatCount(
                lerpDouble(_countFrom, _countTo, _countUp.value) ?? _countTo,
              )
            : MoneyDisplay.formatEditableInput(
                rawValue: _controller.text,
                currency: widget.currency,
                withSymbol: false,
                appLocale: Localizations.localeOf(context),
              );
        final exprT = _expression.value.clamp(0.0, 1.15);

        final amountRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (widget.showCurrencyPrefix) ...[
              // Never animated — keeps ₿ / R$ rock-steady while typing.
              Text(symbol, style: symbolStyle),
              const SizedBox(width: 8),
            ],
            reduce || _counting
                ? Text(display, style: style)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      for (final g in _glyphs)
                        _RevolutDigit(
                          key: ValueKey<int>(g.id),
                          char: g.char,
                          style: style,
                          enter: g.enter,
                          expandWidth: g.expandWidth,
                          exiting: g.exiting,
                          onExitComplete: () => _onGlyphExitComplete(g.id),
                        ),
                    ],
                  ),
            const SizedBox(width: 3),
            Baseline(
              baseline: baseSize * 0.92,
              baselineType: TextBaseline.alphabetic,
              child: Container(
                width: 2.5,
                height: baseSize * 0.92,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        );

        return Semantics(
          liveRegion: true,
          label: '$symbol $display',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: exprT.clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: exprT.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(
                        6.3 * (1 - exprT.clamp(0.0, 1.0)),
                        4.9 * (1 - exprT.clamp(0.0, 1.0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          hasExpression ? expression : ' ',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.inter(
                            color: _C.muted,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Visual layer is animated; TextField stays unscaled so IME works.
              SizedBox(
                width: double.infinity,
                height: baseSize * 1.35,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    IgnorePointer(
                      child: FittedBox(fit: BoxFit.scaleDown, child: amountRow),
                    ),
                    // Full-bleed invisible editor — never inside Transform.
                    Positioned.fill(
                      child: TextField(
                        key: const ValueKey('movement-amount-input'),
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.done,
                        style: style.copyWith(
                          color: Colors.transparent,
                          height: 1.35,
                        ),
                        // Native caret misaligns vs prefixed visual digits —
                        // we paint a custom caret at the trailing edge instead.
                        cursorColor: Colors.transparent,
                        cursorWidth: 0,
                        showCursor: false,
                        enableSuggestions: false,
                        autocorrect: false,
                        smartDashesType: SmartDashesType.disabled,
                        smartQuotesType: SmartQuotesType.disabled,
                        decoration: _bareInputDecoration,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        onChanged: _onChanged,
                        onTap: () {
                          // Always edit at the trailing edge.
                          _controller.selection = TextSelection.collapsed(
                            offset: _controller.text.length,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmountGlyph {
  final int id;
  final String char;
  final bool enter;

  /// Layout width animates with the glyph (insert → grow, delete → shrink).
  final bool expandWidth;
  final bool exiting;

  const _AmountGlyph({
    required this.id,
    required this.char,
    required this.enter,
    required this.expandWidth,
    required this.exiting,
  });
}

/// Digit / decimal / grouping sep — insert & delete share the same motion.
class _RevolutDigit extends StatefulWidget {
  final String char;
  final TextStyle style;
  final bool enter;
  final bool expandWidth;
  final bool exiting;
  final VoidCallback? onExitComplete;

  const _RevolutDigit({
    super.key,
    required this.char,
    required this.style,
    required this.enter,
    this.expandWidth = false,
    this.exiting = false,
    this.onExitComplete,
  });

  @override
  State<_RevolutDigit> createState() => _RevolutDigitState();
}

class _RevolutDigitState extends State<_RevolutDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  late final Animation<double> _appear;

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: KeroseneMotion.inputDigit);
    _appear = CurvedAnimation(parent: _t, curve: KeroseneMotion.standard);
    if (widget.exiting) {
      _t.value = 1;
      _runExit();
    } else if (widget.enter) {
      _t.forward();
    } else {
      _t.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _RevolutDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exiting && !oldWidget.exiting) {
      _runExit();
    } else if (widget.enter && !oldWidget.enter && !widget.exiting) {
      // Grouping side-change (insert or delete) — pulse only this digit.
      _t.forward(from: 0);
    }
  }

  void _runExit() {
    _t.reverse().whenComplete(() {
      if (mounted) widget.onExitComplete?.call();
    });
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, child) {
        final t = _appear.value;
        final scale = 0.72 + 0.28 * t;
        Widget glyph = Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          child: child,
        );
        // Width grow/shrink pushes neighbors (digits, `.`, `,`) smoothly.
        if (widget.expandWidth || widget.exiting) {
          glyph = ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: t <= 0 ? 0.001 : t,
              child: glyph,
            ),
          );
        }
        return glyph;
      },
      child: Text(widget.char, style: widget.style),
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
  final bool showCurrencyPrefix;

  const _AmountHero({
    required this.amountInput,
    required this.currency,
    required this.hasWarning,
    required this.showCursor,
    this.showCurrencyPrefix = false,
  });

  @override
  State<_AmountHero> createState() => _AmountHeroState();
}

class _AmountHeroState extends State<_AmountHero>
    with TickerProviderStateMixin {
  static const _pulseScale = 0.985;
  static const _digitIn = KeroseneMotion.inputHeroDigit;
  static const _settle = KeroseneMotion.inputHeroSettle;
  static const _shakeMs = KeroseneMotion.inputHeroShake;

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
      duration: KeroseneMotion.inputCursor,
    );
    _pulse = AnimationController(vsync: this, duration: _digitIn);
    _shake = AnimationController(vsync: this, duration: _shakeMs);

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: _pulseScale,
        ).chain(CurveTween(curve: KeroseneMotion.standard)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _pulseScale,
          end: 1.0,
        ).chain(CurveTween(curve: KeroseneMotion.standard)),
        weight: 60,
      ),
    ]).animate(_pulse);

    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.72,
        ).chain(CurveTween(curve: KeroseneMotion.standard)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.72,
          end: 1.0,
        ).chain(CurveTween(curve: KeroseneMotion.standard)),
        weight: 65,
      ),
    ]).animate(_pulse);

    // Micro horizontal shake: 0 → 2 → -2 → 1 → 0 (logical px).
    _shakeX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 2.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: -2.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _shake, curve: KeroseneMotion.standard));

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
    return (prefix: chars.skipLast(1).toString(), tail: chars.last);
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
    final digitDuration = KeroseneMotion.duration(
      context,
      KeroseneMotion.inputAmountMorph,
    );

    Widget amountRow;
    if (reduce) {
      amountRow = Text(display, style: style);
    } else {
      amountRow = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (parts.prefix.isNotEmpty) Text(parts.prefix, style: style),
          AnimatedSwitcher(
            duration: digitDuration,
            switchInCurve: KeroseneMotion.standard,
            switchOutCurve: KeroseneMotion.exit,
            layoutBuilder: (current, _) => current ?? const SizedBox.shrink(),
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: KeroseneMotion.standard,
              );
              final scale = Tween<double>(begin: 0.80, end: 1).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: KeroseneMotion.spring,
                ),
              );
              return FadeTransition(
                opacity: fade,
                child: ScaleTransition(scale: scale, child: child),
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

    final symbol = MoneyDisplay.tickerSymbolFor(widget.currency);
    final symbolStyle = widget.currency == Currency.btc
        ? style.copyWith(
            fontWeight: FontWeight.lerp(
              style.fontWeight ?? FontWeight.w600,
              FontWeight.w100,
              0.4,
            ),
          )
        : style;

    Widget content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showCurrencyPrefix) ...[
            Text(symbol, style: symbolStyle),
            const SizedBox(width: 10),
          ],
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
      return Semantics(liveRegion: true, label: display, child: content);
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
      duration: KeroseneMotion.inputSwap,
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
      KeroseneMotion.inputHeroSettle,
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
        children: [
          Flexible(
            child: reduce
                ? label
                : AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: KeroseneMotion.standard,
                    switchOutCurve: KeroseneMotion.exit,
                    child: label,
                  ),
          ),
          if (widget.onTap != null) ...[
            const SizedBox(width: 6),
            RotationTransition(
              turns: Tween<double>(begin: 0, end: 0.5).animate(
                CurvedAnimation(
                  parent: _swapSpin,
                  curve: KeroseneMotion.standard,
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

  const _ContextPanel({this.availableLabel, this.feeLabel, this.warningLabel});

  @override
  Widget build(BuildContext context) {
    // No gray panel — flat, centered meta lines under the amount.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (availableLabel != null)
          _ContextLine(label: _availableLabel(context), value: availableLabel!),
        if (availableLabel != null && feeLabel != null)
          const SizedBox(height: 8),
        if (feeLabel != null)
          _ContextLine(
            label: context.tr.sendReviewNetworkFee,
            value: feeLabel!,
          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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
      duration: KeroseneMotion.inputPress,
      reverseDuration: KeroseneMotion.inputPressReverseFast,
    );
    _scale = Tween<double>(begin: 1.0, end: _pressScale).animate(
      CurvedAnimation(
        parent: _press,
        curve: KeroseneMotion.exit,
        reverseCurve: KeroseneMotion.standard,
      ),
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
          splashColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
          highlightColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.04),
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
  final bool compact;

  const _CtaBar({
    required this.label,
    required this.enabled,
    required this.isBusy,
    required this.onCta,
    this.compact = false,
  });

  @override
  State<_CtaBar> createState() => _CtaBarState();
}

class _CtaBarState extends State<_CtaBar> with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _press;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.inputSpin,
    );
    _press = AnimationController(
      vsync: this,
      duration: KeroseneMotion.inputPress,
      reverseDuration: KeroseneMotion.inputPressReverseSoft,
    );
    _pressScale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(
        parent: _press,
        curve: KeroseneMotion.exit,
        reverseCurve: KeroseneMotion.standard,
      ),
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
    _press.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (!widget.enabled || widget.isBusy) return;
    if (!KeroseneMotion.reduceMotion(context)) {
      unawaited(_animatePress());
    }
    widget.onCta();
  }

  Future<void> _animatePress() async {
    await _press.forward(from: 0);
    if (mounted) await _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: widget.enabled ? _C.bg : _C.muted,
    );

    return Semantics(
      key: const ValueKey('transaction-value-entry-cta'),
      button: true,
      enabled: widget.enabled && !widget.isBusy,
      label: widget.label,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl2,
          widget.compact ? 2 : AppSpacing.xs,
          AppSpacing.xl2,
          widget.compact ? 8 : AppSpacing.base,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final height = widget.compact
                ? 48.0
                : (AppSpacing.xxxl > AppSpacing.minTouch
                      ? 54.0
                      : AppSpacing.minTouch.toDouble());
            return ScaleTransition(
              scale: _pressScale,
              child: AnimatedContainer(
                duration: KeroseneMotion.inputCta,
                curve: KeroseneMotion.standardInOut,
                width: widget.isBusy ? height : maxWidth,
                height: height,
                decoration: BoxDecoration(
                  color: widget.enabled || widget.isBusy ? _C.text : _C.chip,
                  borderRadius: BorderRadius.circular(
                    widget.isBusy ? height / 2 : 999,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey(
                      'transaction-value-entry-cta-hit-target',
                    ),
                    borderRadius: BorderRadius.circular(
                      widget.isBusy ? height / 2 : 999,
                    ),
                    onTap: widget.enabled && !widget.isBusy ? _onTap : null,
                    child: Center(
                      child: widget.isBusy
                          ? RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _spinController,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle:
                                        _spinController.value *
                                        2 *
                                        3.141592653589793,
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
                                      child: CircularProgressIndicator(
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
              ),
            );
          },
        ),
      ),
    );
  }
}

class _C {
  const _C._();

  static Color get bg => KeroseneBrandTokens.background;
  static Color get text => KeroseneBrandTokens.textPrimary;
  static Color get muted => KeroseneBrandTokens.textMuted;
  static Color get chip => KeroseneBrandTokens.surfaceElevated;
  static const warning = KeroseneBrandTokens.warning;
}
