import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:kerosene/core/providers/recent_transaction_destinations_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:kerosene/features/movement/domain/payment_intent.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/screens/send_money_formatters.dart';
import 'package:kerosene/features/movement/copy/send_money_copy.dart';
import 'package:kerosene/features/movement/widgets/internal_recent_avatar.dart';

class SendDestinationStep extends StatelessWidget {
  final TextEditingController receiverController;
  final SendDestinationAnalysis analysis;
  final List<RecentTransactionDestination> recentDestinations;
  final bool isLoading;
  final VoidCallback onDestinationChanged;
  final VoidCallback onScan;
  final VoidCallback onContinue;
  final ValueChanged<RecentTransactionDestination> onRecentDestinationSelected;

  /// Leading control: wizard back when [canWizardBack], else close flow.
  final VoidCallback onLeading;
  final bool canWizardBack;

  /// Live capabilities resolve (username / internal).
  final ResolvedPaymentIntent? resolvedIntent;
  final bool isLiveResolving;
  final String? liveResolveError;
  final ValueChanged<PaymentRail>? onRailSelected;

  const SendDestinationStep({
    super.key,
    required this.receiverController,
    required this.analysis,
    required this.recentDestinations,
    required this.isLoading,
    required this.onDestinationChanged,
    required this.onScan,
    required this.onContinue,
    required this.onRecentDestinationSelected,
    required this.onLeading,
    this.canWizardBack = false,
    this.resolvedIntent,
    this.isLiveResolving = false,
    this.liveResolveError,
    this.onRailSelected,
  });

  static const internalBlack = KeroseneBrandTokens.background;
  static const internalSurfaceHigh = KeroseneBrandTokens.surfaceHigh;
  static const internalBorder = KeroseneBrandTokens.border;
  static const internalText = KeroseneBrandTokens.textPrimary;
  static const internalMutedText = KeroseneBrandTokens.textMuted;

  @override
  Widget build(BuildContext context) {
    final destination = receiverController.text.trim();
    final isValidDestination = analysis.isValid;
    final filteredContacts = _filterRecentDestinations(
      recentDestinations,
      destination,
    );
    final hasContacts = filteredContacts.isNotEmpty;
    final showEmptyContacts =
        recentDestinations.isEmpty && destination.length < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              24,
              hasContacts || showEmptyContacts ? 24 : 30,
              24,
              hasContacts || showEmptyContacts ? 28 : 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: context.responsive.appColumnConstraints,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DestinationHeader(
                      hasContacts: hasContacts || showEmptyContacts,
                      canWizardBack: canWizardBack,
                      onLeading: onLeading,
                    ),
                    SizedBox(height: hasContacts || showEmptyContacts ? 32 : 26),
                    _DestinationInputSection(
                      controller: receiverController,
                      analysis: analysis,
                      isLoading: isLoading,
                      largeLabel: !hasContacts && !showEmptyContacts,
                      onChanged: onDestinationChanged,
                      onScan: onScan,
                    ),
                    if (destination.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          // Only real resolve status/errors — no type-detection labels.
                          final message = _resolveStatusMessage(
                            context,
                            resolved: resolvedIntent,
                            liveError: liveResolveError,
                            liveResolving: isLiveResolving,
                          );
                          if (message == null || message.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              children: [
                                _DestinationFeedback(
                                  analysis: analysis,
                                  message: message,
                                ),
                                if (resolvedIntent != null || analysis.isValid)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      switchInCurve: Curves.easeIn,
                                      switchOutCurve: Curves.easeOut,
                                      child: _ReceiverProfileCard(
                                        key: ValueKey(destination),
                                        analysis: analysis,
                                        resolved: resolvedIntent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    if (hasContacts) ...[
                      const SizedBox(height: 40),
                      _FrequentContactsSection(
                        destinations:
                            filteredContacts.take(3).toList(growable: false),
                        onSelected: onRecentDestinationSelected,
                      ),
                      const SizedBox(height: 36),
                      _AllContactsSection(
                        destinations: filteredContacts,
                        onSelected: onRecentDestinationSelected,
                      ),
                    ] else if (showEmptyContacts) ...[
                      const SizedBox(height: 42),
                      const _EmptyContactsState(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _DestinationBottomAction(
          hasContacts: hasContacts || showEmptyContacts,
          enabled: isValidDestination,
          isLoading: isLoading,
          onTap: onContinue,
        ),
      ],
    );
  }

  /// Local prefix search (≥3 chars) over recent destinations (username/label/address).
  static List<RecentTransactionDestination> _filterRecentDestinations(
    List<RecentTransactionDestination> all,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return all;
    final needle = q.startsWith('@') ? q.substring(1) : q;
    return all.where((dest) {
      final label = (dest.label ?? '').toLowerCase();
      final address = dest.address.toLowerCase();
      final labelBare =
          label.startsWith('@') ? label.substring(1) : label;
      final addressBare =
          address.startsWith('@') ? address.substring(1) : address;
      return labelBare.contains(needle) ||
          addressBare.contains(needle) ||
          label.contains(q) ||
          address.contains(q);
    }).toList(growable: false);
  }

  /// Live resolve only — no "detected internal/on-chain/…" helper labels.
  String? _resolveStatusMessage(
    BuildContext context, {
    required ResolvedPaymentIntent? resolved,
    required String? liveError,
    required bool liveResolving,
  }) {
    if (liveError != null && liveError.trim().isNotEmpty) {
      return liveError.trim();
    }
    if (liveResolving) {
      return SendMoneyCopy.progressResolving(context);
    }
    if (resolved != null) {
      if (resolved.blockers.isNotEmpty) {
        return resolved.blockers.first.message;
      }
      // Prefer blockers only; skip generic explainWhy noise as a label.
    }
    return null;
  }
}

class _ReceiverProfileCard extends StatelessWidget {
  final SendDestinationAnalysis analysis;
  final ResolvedPaymentIntent? resolved;

  const _ReceiverProfileCard({
    super.key,
    required this.analysis,
    this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    String displayName = '';
    String subtext = '';

    if (analysis.isInternal) {
      displayName = analysis.label ?? analysis.normalizedValue;
      subtext = 'Kerosene User';
    } else if (analysis.isOnChain) {
      displayName = 'Endereço On-chain';
      final address = analysis.normalizedValue;
      if (address.length > 12) {
        subtext = '${address.substring(0, 6)}...${address.substring(address.length - 6)}';
      } else {
        subtext = address;
      }
    } else if (analysis.isLightning) {
      displayName = 'Fatura Lightning';
      subtext = 'Lightning Network';
    } else if (analysis.isPaymentLink) {
      displayName = 'Link de Pagamento';
      subtext = analysis.normalizedValue;
    } else {
      displayName = analysis.normalizedValue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SendDestinationStep.internalSurfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SendDestinationStep.internalBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'receiver_avatar_${analysis.normalizedValue}',
            child: InternalRecentAvatar(
              title: displayName,
              size: 48,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.inter(
                    color: SendDestinationStep.internalText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtext,
                  style: AppTypography.inter(
                    color: SendDestinationStep.internalMutedText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailPicker extends StatelessWidget {
  final List<RailOption> options;
  final PaymentRail selected;
  final ValueChanged<PaymentRail> onSelected;

  const _RailPicker({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Compact rail choice only — no section title / subtitles / stars.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          _RailChip(
            label: _railLabel(context, option.rail),
            selected: option.rail == selected,
            onTap: () => onSelected(option.rail),
          ),
      ],
    );
  }

  static String _railLabel(BuildContext context, PaymentRail rail) {
    final lang = Localizations.localeOf(context).languageCode;
    return switch (rail) {
      PaymentRail.internal => switch (lang) {
          'en' => 'Instant',
          'es' => 'Instantáneo',
          _ => 'Instantâneo',
        },
      PaymentRail.onchain || PaymentRail.coldOnchain => switch (lang) {
          'en' => 'On-chain',
          'es' => 'On-chain',
          _ => 'On-chain',
        },
      PaymentRail.lightning => 'Lightning',
      PaymentRail.paymentLink => switch (lang) {
          'en' => 'Link',
          'es' => 'Link',
          _ => 'Link',
        },
    };
  }
}

class _RailChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RailChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? SendDestinationStep.internalText
        : SendDestinationStep.internalSurfaceHigh;
    final fg = selected
        ? KeroseneBrandTokens.background
        : SendDestinationStep.internalText;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: AppTypography.inter(
              color: fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationHeader extends StatelessWidget {
  final bool hasContacts;
  final bool canWizardBack;
  final VoidCallback onLeading;

  const _DestinationHeader({
    required this.hasContacts,
    required this.canWizardBack,
    required this.onLeading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            onPressed: onLeading,
            tooltip: canWizardBack
                ? MaterialLocalizations.of(context).backButtonTooltip
                : context.tr.close,
            icon: Icon(
              canWizardBack ? KeroseneIcons.back : KeroseneIcons.close,
              size: 24,
            ),
            color: SendDestinationStep.internalText,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
        SizedBox(height: hasContacts ? 18 : 20),
        Text(
          'Para quem você quer enviar dinheiro?',
          textAlign: TextAlign.left,
          style: AppTypography.newsreader(
            color: SendDestinationStep.internalText,
            fontSize: hasContacts ? 30 : 28,
            fontWeight: hasContacts ? FontWeight.w700 : FontWeight.w500,
            height: hasContacts ? 1.12 : 1.2,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _DestinationBottomAction extends StatelessWidget {
  final bool hasContacts;
  final bool enabled;
  final VoidCallback onTap;
  final bool isLoading;

  const _DestinationBottomAction({
    required this.hasContacts,
    required this.enabled,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final actionEnabled = enabled && !isLoading;
    final backgroundColor = !actionEnabled
        ? SendDestinationStep.internalSurfaceHigh.withValues(alpha: 0.64)
        : hasContacts
            ? SendDestinationStep.internalSurfaceHigh
            : SendDestinationStep.internalText;
    final foregroundColor = !actionEnabled
        ? SendDestinationStep.internalMutedText
        : hasContacts
            ? SendDestinationStep.internalText
            : SendDestinationStep.internalBlack;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        color: SendDestinationStep.internalBlack,
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton(
            onPressed: actionEnabled ? onTap : null,
            style: FilledButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: AppTypography.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.2,
              ),
            ),
            child: isLoading
                ? const CupertinoActivityIndicator(radius: 9)
                : Text(context.tr.continueButton),
          ),
        ),
      ),
    );
  }
}

class _DestinationFeedback extends StatelessWidget {
  final SendDestinationAnalysis analysis;
  final String message;

  const _DestinationFeedback({
    required this.analysis,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final invalid = analysis.isInvalid;
    final color = invalid
        ? KeroseneBrandTokens.error
        : SendDestinationStep.internalMutedText;
    final icon = invalid ? KeroseneIcons.warning : KeroseneIcons.info;

    return AnimatedContainer(
      duration: KeroseneMotion.duration(context, KeroseneMotion.short),
      curve: KeroseneMotion.standard,
      padding: invalid
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: invalid
            ? KeroseneBrandTokens.error.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: invalid
            ? Border.all(
                color: KeroseneBrandTokens.error.withValues(alpha: 0.55))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: invalid ? 18 : 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: color,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: SendDestinationStep.internalSurfaceHigh,
            ),
            child: const Center(
              child: Icon(
                KeroseneIcons.userAdd,
                color: SendDestinationStep.internalMutedText,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            SendMoneyCopy.noRecentDestinations(context),
            textAlign: TextAlign.center,
            style: AppTypography.newsreader(
              color: SendDestinationStep.internalText,
              fontSize: 28,
              fontWeight: FontWeight.w500,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            SendMoneyCopy.noRecentDestinationsBody(context),
            textAlign: TextAlign.center,
            style: AppTypography.inter(
              color: SendDestinationStep.internalMutedText,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationInputSection extends StatefulWidget {
  final TextEditingController controller;
  final SendDestinationAnalysis analysis;
  final bool isLoading;
  final bool largeLabel;
  final VoidCallback onChanged;
  final VoidCallback onScan;

  const _DestinationInputSection({
    required this.controller,
    required this.analysis,
    required this.isLoading,
    required this.largeLabel,
    required this.onChanged,
    required this.onScan,
  });

  @override
  State<_DestinationInputSection> createState() =>
      _DestinationInputSectionState();
}

class _DestinationInputSectionState extends State<_DestinationInputSection> {
  late final FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final activeElementColor = _hasFocus
        ? SendDestinationStep.internalText
        : SendDestinationStep.internalMutedText;
    final borderColor = widget.analysis.isInvalid
        ? KeroseneBrandTokens.error
        : widget.isLoading || _hasFocus
            ? activeElementColor
            : SendDestinationStep.internalBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.largeLabel ? 8 : 0),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: (_) => widget.onChanged(),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                cursorColor: SendDestinationStep.internalText,
                textAlign: TextAlign.left,
                style: AppTypography.inter(
                  color: SendDestinationStep.internalText,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  letterSpacing: 0,
                ),
                decoration: InputDecoration(
                  hintText:
                      _hasFocus ? null : SendMoneyCopy.destinationHint(context),
                  hintStyle: AppTypography.inter(
                    color: activeElementColor.withValues(alpha: 0.55),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    letterSpacing: 0,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: KeroseneMotion.duration(context, KeroseneMotion.short),
              child: widget.isLoading
                  ? CupertinoActivityIndicator(
                      key: const ValueKey('destination-loading'),
                      radius: 9,
                      color: activeElementColor,
                    )
                  : const SizedBox(
                      key: ValueKey('destination-loading-empty'),
                      width: 18,
                      height: 18,
                    ),
            ),
            Semantics(
              button: true,
              label: switch (Localizations.localeOf(context).languageCode) {
                'en' => 'Add destination with QR, NFC or paste',
                'es' => 'Agregar destino con QR, NFC o pegar',
                _ => 'Adicionar destino com QR, NFC ou colar',
              },
              child: IconButton(
                onPressed: widget.onScan,
                tooltip: switch (Localizations.localeOf(context).languageCode) {
                  'en' => 'QR, NFC or paste',
                  'es' => 'QR, NFC o pegar',
                  _ => 'QR, NFC ou colar',
                },
                icon: const Icon(KeroseneIcons.scanner, size: 24),
                color: activeElementColor,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
              ),
            ),
          ],
        ),
        AnimatedContainer(
          duration: KeroseneMotion.duration(context, KeroseneMotion.short),
          margin: const EdgeInsets.only(top: 8),
          height: 1,
          color: borderColor,
        ),
      ],
    );
  }
}

class _FrequentContactsSection extends StatelessWidget {
  final List<RecentTransactionDestination> destinations;
  final ValueChanged<RecentTransactionDestination> onSelected;

  const _FrequentContactsSection({
    required this.destinations,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          SendMoneyCopy.frequentDestinations(context),
          style: AppTypography.inter(
            color: SendDestinationStep.internalMutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 126,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return _FrequentContact(
                destination: destinations[index],
                onSelected: onSelected,
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 24),
            itemCount: destinations.length,
          ),
        ),
      ],
    );
  }
}

class _FrequentContact extends StatelessWidget {
  final RecentTransactionDestination destination;
  final ValueChanged<RecentTransactionDestination> onSelected;

  const _FrequentContact({required this.destination, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final title = recentInternalDestinationTitle(destination);
    final subtitle = recentInternalDestinationSubtitle(destination);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelected(destination),
        child: SizedBox(
          width: 104,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              children: [
                InternalRecentAvatar(title: title, size: 64, fontSize: 18),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SendDestinationStep.internalText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SendDestinationStep.internalMutedText,
                        fontSize: 11,
                        height: 1.2,
                        letterSpacing: 0,
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

class _AllContactsSection extends StatelessWidget {
  final List<RecentTransactionDestination> destinations;
  final ValueChanged<RecentTransactionDestination> onSelected;

  const _AllContactsSection(
      {required this.destinations, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          SendMoneyCopy.allDestinations(context),
          style: AppTypography.inter(
            color: SendDestinationStep.internalMutedText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 24),
        for (final destination in destinations)
          _RecentDestinationRow(
            destination: destination,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _RecentDestinationRow extends StatelessWidget {
  final RecentTransactionDestination destination;
  final ValueChanged<RecentTransactionDestination> onSelected;

  const _RecentDestinationRow(
      {required this.destination, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final title = recentInternalDestinationTitle(destination);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: SendDestinationStep.internalText.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(destination),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                InternalRecentAvatar(title: title, size: 48, fontSize: 14),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.newsreader(
                      color: SendDestinationStep.internalText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 0,
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
