import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/payment_intent.dart';
import 'package:kerosene/features/movement/flow/kfe_receiving_capabilities_service.dart';
import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/screens/send_money_formatters.dart';

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
      if (source == SourceCustody.watchOnly) {
        blockers.add(const PaymentBlocker(
          code: PaymentBlockerCode.noCapability,
          message: 'Carteira fria não envia Lightning. Use on-chain.',
        ));
      } else if (source == SourceCustody.internal) {
        // INTERNAL ledger can withdraw via KFE lightning only for *external* invoices.
        // Platform-owned BOLT11 is rewritten to paymentLink (INTERNAL) before submit.
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
      if (source == SourceCustody.watchOnly) {
        return ResolvedPaymentIntent(
          intent: intent,
          source: source,
          selectedRail: PaymentRail.coldOnchain,
          explainWhy:
              'Destino de usuário Kerosene: carteira fria só envia on-chain quando houver endereço.',
          blockers: [
            ...blockers,
            const PaymentBlocker(
              code: PaymentBlockerCode.noCapability,
              message:
                  'Para pagar um usuário Kerosene com carteira fria, use o endereço on-chain do destinatário.',
            ),
          ],
        );
      }
      // Placeholder until capabilities applied via [resolveWithCapabilities].
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: PaymentRail.internal,
        explainWhy: 'Usuário Kerosene — resolvendo capacidades…',
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
  ResolvedPaymentIntent resolveWithCapabilities({
    required PaymentIntent intent,
    required SourceCustody source,
    required KfeReceivingCapabilities capabilities,
    BitcoinNetworkKind expectedNetwork = BitcoinNetworkKind.unknown,
    PaymentRail? userSelectedRail,
    String? sourceWalletId,
    String? sourceWalletAddress,
    String? destOnchainAddress,
  }) {
    final base = resolveLocal(
      intent: intent,
      source: source,
      expectedNetwork: expectedNetwork,
      sourceWalletId: sourceWalletId,
      sourceWalletAddress: sourceWalletAddress,
    );
    if (!intent.isInternal || source == SourceCustody.watchOnly) {
      return base;
    }

    final blockers = List<PaymentBlocker>.from(base.blockers);
    final options = <RailOption>[];

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
      options.add(const RailOption(
        rail: PaymentRail.internal,
        title: 'Instantâneo',
        subtitle: 'Saldo Kerosene · sem taxa de rede',
        recommended: false,
      ));
    }
    if (canOnchain && hasOnchainAddr) {
      options.add(const RailOption(
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
      options.add(const RailOption(
        rail: PaymentRail.lightning,
        title: 'Lightning',
        subtitle: 'Rápido · taxa de roteamento variável',
        recommended: false,
      ));
    }

    if (options.isEmpty) {
      blockers.add(PaymentBlocker(
        code: PaymentBlockerCode.noCapability,
        message: capabilities.missingRequirements.isNotEmpty
            ? 'Destinatário ainda não recebe: ${capabilities.missingRequirements.join(', ')}'
            : 'Este usuário ainda não está pronto para receber.',
      ));
      return ResolvedPaymentIntent(
        intent: intent,
        source: source,
        selectedRail: PaymentRail.internal,
        blockers: blockers,
        explainWhy: 'Sem trilho disponível para este destinatário.',
        amountLocked: intent.hasLockedAmount,
      );
    }

    final preferred = _parsePreferredRail(capabilities.preferredRail);
    PaymentRail selected = userSelectedRail ??
        _pickDefaultRail(
          preferred: preferred,
          options: options,
        );

    // User may pick a rail that is not available — clamp.
    if (!options.any((o) => o.rail == selected)) {
      selected = options.first.rail;
    }

    final marked = options
        .map(
          (o) => RailOption(
            rail: o.rail,
            title: o.title,
            subtitle: o.subtitle,
            recommended: o.rail == selected && userSelectedRail == null,
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
      PaymentRail.coldOnchain => 'Envio cold on-chain.',
    };

    return ResolvedPaymentIntent(
      intent: intent.copyWith(label: displayName),
      source: source,
      selectedRail: selected,
      alternatives: marked,
      destWalletId: canInternal ? capabilities.internalWalletId?.trim() : null,
      destOnchainAddress: hasOnchainAddr ? onchainAddr : null, // non-empty when set
      explainWhy: explain,
      amountLocked: intent.hasLockedAmount,
      blockers: blockers,
    );
  }

  /// Maps a resolved intent into the legacy [SendDestinationAnalysis] used by the send wizard.
  SendDestinationAnalysis toLockedDestination(ResolvedPaymentIntent resolved) {
    final intent = resolved.intent;
    switch (resolved.selectedRail) {
      case PaymentRail.internal:
        final walletId =
            resolved.destWalletId?.trim().isNotEmpty == true
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
    if ((id.isNotEmpty && dest == id) ||
        (addr.isNotEmpty && dest == addr)) {
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

/// Username-like internal destination ready for live capabilities resolve.
bool shouldLiveResolveInternal(PaymentIntent intent) {
  if (!intent.isInternal) return false;
  final v = intent.normalizedValue;
  // UUID wallet ids still resolve, but usernames are the common live case.
  return isValidInternalDestination(v);
}
