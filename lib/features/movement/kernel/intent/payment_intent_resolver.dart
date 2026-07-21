import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';
import 'package:kerosene/features/movement/data/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';

/// Resolves a parsed [PaymentIntent] into an executable rail given source custody
/// and (when needed) KFE receiving capabilities.
class PaymentIntentResolver {
  const PaymentIntentResolver();

  static const PaymentIntentResolver instance = PaymentIntentResolver();

  /// Classifies the send source wallet.
  SourceCustody classifySource(Wallet? wallet) {
    if (wallet == null) return SourceCustody.internal;
    if (wallet.isColdWallet || wallet.isSelfCustody) {
      return SourceCustody.watchOnly;
    }
    if (wallet.isCustodialOnchain) return SourceCustody.custodialOnchain;
    return SourceCustody.internal;
  }

  /// Whether [source] can execute [rail] (origin side of the send matrix).
  ///
  /// Internal custody: ledger + Lightning + on-chain L1.
  /// Custodial on-chain: L1 only.
  /// Cold / watch-only: L1 only (`onchain` / `coldOnchain`).
  static bool sourceCanExecute(PaymentRail rail, SourceCustody source) {
    switch (rail) {
      case PaymentRail.internal:
      case PaymentRail.paymentLink:
        return source == SourceCustody.internal;
      case PaymentRail.lightning:
        return source == SourceCustody.internal;
      case PaymentRail.onchain:
        return source == SourceCustody.internal ||
            source == SourceCustody.custodialOnchain ||
            source == SourceCustody.watchOnly;
      case PaymentRail.coldOnchain:
        return source == SourceCustody.watchOnly;
    }
  }

  static bool anySourceCanExecute(
    PaymentRail rail,
    Iterable<SourceCustody> sources,
  ) {
    for (final source in sources) {
      if (sourceCanExecute(rail, source)) return true;
    }
    return false;
  }

  /// Pure resolve when no network call is required (non-username destinations).
  ResolvedPaymentIntent resolveLocal({
    required PaymentIntent intent,
    required SourceCustody source,
    BitcoinNetworkKind expectedNetwork = BitcoinNetworkKind.unknown,
    PaymentRail? userSelectedRail,
    String? sourceWalletId,
    String? sourceWalletAddress,
  }) {
    if (intent.isEmpty) {
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: PaymentRail.internal,
        blockers: const [
          PaymentBlocker(
            code: PaymentBlockerCode.invalidDestination,
            message: 'Informe um destino para continuar.',
          ),
        ],
      );
    }
    if (intent.isInvalid) {
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: PaymentRail.internal,
        blockers: [
          PaymentBlocker(
            code: PaymentBlockerCode.invalidDestination,
            message: intent.invalidReason == 'whitespace'
                ? 'Remova espaços do destino.'
                : 'Destino não reconhecido.',
          ),
        ],
      );
    }

    final blockers = <PaymentBlocker>[
      ..._selfPayBlockers(
        intent: intent,
        sourceWalletId: sourceWalletId,
        sourceWalletAddress: sourceWalletAddress,
      ),
      ..._networkBlockers(intent: intent, expectedNetwork: expectedNetwork),
    ];

    if (intent.isPaymentLink) {
      if (source == SourceCustody.watchOnly) {
        blockers.add(const PaymentBlocker(
          code: PaymentBlockerCode.noCapability,
          message:
              'Carteira fria não paga link Kerosene pelo ledger. Use um endereço on-chain.',
        ));
      }
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: PaymentRail.paymentLink,
        explainWhy: 'Link de pagamento Kerosene (valor e destino travados).',
        amountLocked: intent.hasLockedAmount,
        blockers: blockers,
      );
    }

    if (intent.isLightning) {
      if (!sourceCanExecute(PaymentRail.lightning, source)) {
        blockers.add(PaymentBlocker(
          code: PaymentBlockerCode.noCapability,
          message: source == SourceCustody.watchOnly
              ? 'Carteira fria não envia Lightning. Use on-chain.'
              : 'Lightning só é enviado a partir da carteira interna.',
        ));
      }
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: PaymentRail.lightning,
        explainWhy:
            'Invoice Lightning externo. Invoices da plataforma usam pagamento interno.',
        amountLocked: intent.hasLockedAmount,
        blockers: blockers,
      );
    }

    if (intent.isOnchain) {
      final rail = source == SourceCustody.watchOnly
          ? PaymentRail.coldOnchain
          : PaymentRail.onchain;
      if (!sourceCanExecute(rail, source) &&
          !sourceCanExecute(PaymentRail.onchain, source)) {
        blockers.add(const PaymentBlocker(
          code: PaymentBlockerCode.noCapability,
          message: 'Esta carteira não envia on-chain.',
        ));
      }
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: rail,
        destOnchainAddress: intent.normalizedValue,
        explainWhy: source == SourceCustody.watchOnly
            ? 'On-chain a partir da carteira fria (assinatura no aparelho).'
            : 'Endereço Bitcoin on-chain detectado.',
        amountLocked: intent.hasLockedAmount,
        blockers: blockers,
      );
    }

    // Internal username / uuid — needs capabilities for full resolve.
    if (intent.isInternal) {
      // Placeholder until capabilities applied via [resolveWithCapabilities].
      // Cold may still continue when dest has an on-chain receive address.
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: source == SourceCustody.watchOnly
            ? PaymentRail.coldOnchain
            : PaymentRail.internal,
        explainWhy: source == SourceCustody.watchOnly
            ? 'Destino de usuário Kerosene: carteira fria só envia on-chain quando houver endereço.'
            : 'Usuário Kerosene — resolvendo capacidades…',
        amountLocked: intent.hasLockedAmount,
        blockers: blockers,
      );
    }

    return ResolvedPaymentIntent(
      intent: intent,
      source: source,
      selectedRail: PaymentRail.internal,
      blockers: [
        ...blockers,
        const PaymentBlocker(
          code: PaymentBlockerCode.invalidDestination,
          message: 'Destino não reconhecido.',
        ),
      ],
    );
  }

  /// Applies KFE receiving capabilities for username / internal destinations.
  ///
  /// Rails offered = what the destination can receive ∩ what [availableSources]
  /// (or the selected [source]) can execute.
  ResolvedPaymentIntent resolveWithCapabilities({
    required PaymentIntent intent,
    required SourceCustody source,
    required KfeReceivingCapabilities capabilities,
    BitcoinNetworkKind expectedNetwork = BitcoinNetworkKind.unknown,
    PaymentRail? userSelectedRail,
    String? sourceWalletId,
    String? sourceWalletAddress,
    String? destOnchainAddress,
    Iterable<SourceCustody>? availableSources,
  }) {
    final base = resolveLocal(
      intent: intent,
      source: source,
      expectedNetwork: expectedNetwork,
      sourceWalletId: sourceWalletId,
      sourceWalletAddress: sourceWalletAddress,
    );
    if (!intent.isInternal) {
      return base;
    }

    final sources = <SourceCustody>[
      ...(availableSources ?? const <SourceCustody>[]),
    ];
    if (sources.isEmpty) {
      sources.add(source);
    }

    final blockers = List<PaymentBlocker>.from(base.blockers);
    final destOptions = <RailOption>[];

    final canInternal = capabilities.canReceiveInternal &&
        (capabilities.internalWalletId?.trim().isNotEmpty ?? false);
    final canLightning = capabilities.canReceiveLightning;
    // Prefer explicit destOnchainAddress; fall back to capabilities (Fase A API).
    final onchainAddr = (destOnchainAddress?.trim().isNotEmpty == true
            ? destOnchainAddress!.trim()
            : capabilities.onchainReceiveAddress?.trim()) ??
        '';
    final hasOnchainAddr = onchainAddr.isNotEmpty;
    final canOnchain = capabilities.canReceiveOnchain || hasOnchainAddr;

    if (canInternal) {
      destOptions.add(const RailOption(
        rail: PaymentRail.internal,
        title: 'Instantâneo',
        subtitle: 'Saldo Kerosene · sem taxa de rede',
        recommended: false,
      ));
    }
    if (canOnchain && hasOnchainAddr) {
      destOptions.add(const RailOption(
        rail: PaymentRail.onchain,
        title: 'Bitcoin on-chain',
        subtitle: 'Rede Bitcoin · confirmações na chain',
        recommended: false,
      ));
    }
    // Network Lightning only when destination is already an LN executable
    // (bolt11/LNURL/address). Kerosene usernames use INTERNAL ledger — there is
    // no invoice to pay just because canReceiveLightning is true.
    if (canLightning &&
        _isExecutableLightningDestination(intent.normalizedValue)) {
      destOptions.add(const RailOption(
        rail: PaymentRail.lightning,
        title: 'Lightning',
        subtitle: 'Rápido · taxa de roteamento variável',
        recommended: false,
      ));
    }

    // Destination ∩ any available source custody.
    final options = destOptions
        .where((o) => anySourceCanExecute(o.rail, sources))
        .toList(growable: false);

    // Prefer rails the current source can execute. If none match but another
    // available custody can, keep those options so the wallet step can switch.
    final compatibleWithSource = options
        .where((o) => sourceCanExecute(o.rail, source))
        .toList(growable: false);
    final selectable =
        compatibleWithSource.isNotEmpty ? compatibleWithSource : options;

    if (selectable.isEmpty) {
      final message = _noIntersectMessage(
        capabilities: capabilities,
        destHadRails: destOptions.isNotEmpty,
        source: source,
        sources: sources,
      );
      blockers.add(PaymentBlocker(
        code: PaymentBlockerCode.noCapability,
        message: message,
      ));
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: source == SourceCustody.watchOnly
            ? PaymentRail.coldOnchain
            : PaymentRail.internal,
        blockers: blockers,
        explainWhy: 'Sem trilho compatível entre origem e destinatário.',
        amountLocked: intent.hasLockedAmount,
      );
    }

    final preferred = _parsePreferredRail(capabilities.preferredRail);
    PaymentRail selected = userSelectedRail ??
        _pickDefaultRail(
          preferred: preferred,
          options: selectable,
        );

    // User may pick a rail that is not available — clamp.
    if (!selectable.any((o) => o.rail == selected)) {
      selected = selectable.first.rail;
    }

    // Cold executes L1 as coldOnchain rail for locking/signing path.
    if (selected == PaymentRail.onchain && source == SourceCustody.watchOnly) {
      selected = PaymentRail.coldOnchain;
    }

    final marked = selectable
        .map(
          (o) => RailOption(
            rail: o.rail,
            title: o.title,
            subtitle: o.subtitle,
            recommended: userSelectedRail == null &&
                (o.rail == selected ||
                    (o.rail == PaymentRail.onchain &&
                        selected == PaymentRail.coldOnchain)),
          ),
        )
        .toList(growable: false);

    final displayName = capabilities.receiverDisplayName.trim().isNotEmpty
        ? capabilities.receiverDisplayName.trim()
        : intent.normalizedValue;

    final explain = switch (selected) {
      PaymentRail.internal =>
        '$displayName recebe instantâneo no saldo Kerosene.',
      PaymentRail.onchain =>
        '$displayName · envio on-chain para o endereço de recebimento.',
      PaymentRail.lightning => '$displayName · pagamento Lightning.',
      PaymentRail.paymentLink => 'Link de pagamento.',
      PaymentRail.coldOnchain =>
        '$displayName · on-chain a partir da carteira fria.',
    };

    return ResolvedPaymentIntent(
      intent: intent.copyWith(label: displayName),
      source: source,
      selectedRail: selected,
      alternatives: marked,
      destWalletId: canInternal ? capabilities.internalWalletId?.trim() : null,
      destOnchainAddress: hasOnchainAddr ? onchainAddr : null,
      explainWhy: explain,
      amountLocked: intent.hasLockedAmount,
      blockers: blockers,
    );
  }

  String _noIntersectMessage({
    required KfeReceivingCapabilities capabilities,
    required bool destHadRails,
    required SourceCustody source,
    required List<SourceCustody> sources,
  }) {
    if (!destHadRails) {
      return capabilities.missingRequirements.isNotEmpty
          ? 'Destinatário ainda não recebe: ${capabilities.missingRequirements.join(', ')}'
          : 'Este usuário ainda não está pronto para receber.';
    }
    if (source == SourceCustody.watchOnly ||
        sources.every((s) => s == SourceCustody.watchOnly)) {
      return 'Para pagar este usuário com carteira fria, o destinatário precisa de endereço on-chain.';
    }
    if (!anySourceCanExecute(PaymentRail.internal, sources) &&
        capabilities.canReceiveInternal) {
      return 'Este destinatário só recebe no ledger interno. Use a carteira interna.';
    }
    return 'Nenhuma das suas carteiras consegue enviar neste trilho para este destinatário.';
  }

  /// Maps a resolved intent into the legacy [SendDestinationAnalysis] used by the send wizard.
  SendDestinationAnalysis toLockedDestination(ResolvedPaymentIntent resolved) {
    final intent = resolved.intent;
    switch (resolved.selectedRail) {
      case PaymentRail.internal:
        final walletId = resolved.destWalletId?.trim().isNotEmpty == true
            ? resolved.destWalletId!.trim()
            : intent.normalizedValue;
        return SendDestinationAnalysis(
          type: SendDestinationType.internal,
          normalizedValue: walletId,
          amountBtc: intent.amountBtc,
          label: intent.label,
          message: intent.message,
        );
      case PaymentRail.paymentLink:
        return SendDestinationAnalysis(
          type: SendDestinationType.paymentLink,
          normalizedValue: intent.normalizedValue,
          paymentLinkId: intent.paymentLinkId,
          amountBtc: intent.amountBtc,
          label: intent.label,
          message: intent.message,
        );
      case PaymentRail.lightning:
        // Only lock as Lightning when we have an executable LN destination
        // (bolt11 / LNURL / address / keysend). Kerosene users resolve to a
        // wallet UUID — that is INTERNAL ledger, never externalReference LN.
        final value = intent.normalizedValue.trim();
        if (_isExecutableLightningDestination(value)) {
          return SendDestinationAnalysis(
            type: SendDestinationType.lightning,
            normalizedValue: value,
            amountBtc: intent.amountBtc,
            label: intent.label,
            message: intent.message,
          );
        }
        final walletId = resolved.destWalletId?.trim().isNotEmpty == true
            ? resolved.destWalletId!.trim()
            : value;
        return SendDestinationAnalysis(
          type: SendDestinationType.internal,
          normalizedValue: walletId,
          amountBtc: intent.amountBtc,
          label: intent.label,
          message: intent.message,
        );
      case PaymentRail.onchain:
      case PaymentRail.coldOnchain:
        final addr = resolved.destOnchainAddress?.trim().isNotEmpty == true
            ? resolved.destOnchainAddress!.trim()
            : intent.normalizedValue;
        return SendDestinationAnalysis(
          type: SendDestinationType.onChain,
          normalizedValue: addr,
          amountBtc: intent.amountBtc,
          label: intent.label,
          message: intent.message,
          detectedOnchainNetwork: inferBitcoinNetworkFromAddress(addr),
        );
    }
  }

  PaymentRail _pickDefaultRail({
    required PaymentRail? preferred,
    required List<RailOption> options,
  }) {
    if (preferred != null && options.any((o) => o.rail == preferred)) {
      return preferred;
    }
    // Prefer internal when available — best UX for Kerosene users.
    final internal = options.where((o) => o.rail == PaymentRail.internal);
    if (internal.isNotEmpty) return PaymentRail.internal;
    return options.first.rail;
  }

  PaymentRail? _parsePreferredRail(String raw) {
    final n = raw.trim().toUpperCase();
    if (n.isEmpty) return null;
    if (n.contains('LIGHT') || n == 'LN') return PaymentRail.lightning;
    if (n.contains('ONCHAIN') || n.contains('ON_CHAIN') || n == 'BITCOIN') {
      return PaymentRail.onchain;
    }
    if (n.contains('INTERNAL') || n == 'KFE' || n == 'LEDGER') {
      return PaymentRail.internal;
    }
    return null;
  }

  /// True when [value] can be paid on the Lightning network without further
  /// invoice creation (bolt11, LNURL, LUD-16 address, keysend pubkey).
  static bool _isExecutableLightningDestination(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    var v = trimmed;
    if (v.toLowerCase().startsWith('lightning:')) {
      v = v.substring('lightning:'.length).trim();
      if (v.startsWith('//')) v = v.substring(2).trim();
    }
    final lower = v.toLowerCase();
    if (RegExp(r'^(lnbc|lntb|lnbcrt|lnsb|lntbs)[0-9a-z]+$').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^lnurl1[0-9a-z]+$').hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'^[0-9a-f]{66}$').hasMatch(lower)) {
      return true;
    }
    // Lightning Address (external), not Kerosene username.
    if (RegExp(
      r'^[a-zA-Z0-9._%+\-]{1,64}@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,63}$',
    ).hasMatch(v)) {
      return true;
    }
    return false;
  }

  List<PaymentBlocker> _selfPayBlockers({
    required PaymentIntent intent,
    String? sourceWalletId,
    String? sourceWalletAddress,
  }) {
    final dest = intent.normalizedValue.trim().toLowerCase();
    if (dest.isEmpty) return const [];
    final id = sourceWalletId?.trim().toLowerCase() ?? '';
    final addr = sourceWalletAddress?.trim().toLowerCase() ?? '';
    if ((id.isNotEmpty && dest == id) || (addr.isNotEmpty && dest == addr)) {
      return const [
        PaymentBlocker(
          code: PaymentBlockerCode.selfPay,
          message: 'Não é possível enviar para a mesma carteira de origem.',
        ),
      ];
    }
    return const [];
  }

  List<PaymentBlocker> _networkBlockers({
    required PaymentIntent intent,
    required BitcoinNetworkKind expectedNetwork,
  }) {
    if (!intent.isOnchain || expectedNetwork == BitcoinNetworkKind.unknown) {
      return const [];
    }
    if (intent.detectedOnchainNetwork == BitcoinNetworkKind.unknown) {
      return const [];
    }
    if (intent.detectedOnchainNetwork != expectedNetwork) {
      return [
        PaymentBlocker(
          code: PaymentBlockerCode.networkMismatch,
          message:
              'Rede do endereço (${bitcoinNetworkDisplayName(intent.detectedOnchainNetwork)}) '
              'não confere com a rede do app (${bitcoinNetworkDisplayName(expectedNetwork)}).',
        ),
      ];
    }
    return const [];
  }
}

/// Helper for call sites that only have a [Wallet].
SourceCustody sourceCustodyOf(Wallet? wallet) =>
    PaymentIntentResolver.instance.classifySource(wallet);

/// Whether [wallet] can fund [rail] (wallet step filter).
bool walletMatchesSendRail(Wallet wallet, PaymentRail? rail) {
  if (rail == null) {
    return wallet.spendable || wallet.isColdWallet || wallet.isSelfCustody;
  }
  final custody = sourceCustodyOf(wallet);
  if (rail == PaymentRail.onchain || rail == PaymentRail.coldOnchain) {
    final canExecute = PaymentIntentResolver.sourceCanExecute(
          PaymentRail.onchain,
          custody,
        ) ||
        PaymentIntentResolver.sourceCanExecute(
          PaymentRail.coldOnchain,
          custody,
        );
    if (!canExecute) return false;

    if (wallet.isInternalCustody || wallet.isCustodialOnchain) {
      return wallet.spendable;
    }
    return wallet.isColdWallet || wallet.isSelfCustody;
  }

  if (!PaymentIntentResolver.sourceCanExecute(rail, custody)) {
    return false;
  }

  return wallet.isInternalCustody && wallet.spendable;
}

/// Username-like internal destination ready for live capabilities resolve.
bool shouldLiveResolveInternal(PaymentIntent intent) {
  if (!intent.isInternal) return false;
  final v = intent.normalizedValue;
  // UUID wallet ids still resolve, but usernames are the common live case.
  return isValidInternalDestination(v);
}
