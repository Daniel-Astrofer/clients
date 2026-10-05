// architecture-allow-large-file: receive rail state and request lifecycle are
// kept together to preserve backend and navigation contracts.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/theme/theme_token_bridge.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/domain/entities/external_transfer.dart';
import 'package:kerosene/features/movement/domain/entities/onchain_address_allocation.dart';
import 'package:kerosene/app/storage/activity_archive_store.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/design_system/components/financial/confirmation_surface.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/financial_surface_provider.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_flow_layout.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_network_picker.dart';
import 'receive_request_flow_components.dart';

enum ReceiveRequestStage { qr, confirmations, identified }

SendFlowTheme _flowTokens() => SendFlowTheme.forVariant(
      ThemeTokenBridge.isLight ? Brightness.light : Brightness.dark,
    );

Color get _receiveBackground => _flowTokens().background;
Color get _receiveText => _flowTokens().textPrimary;
Color get _receiveMuted => _flowTokens().textMuted;

class ReceiveRequestFlowScreen extends ConsumerStatefulWidget {
  final Wallet wallet;
  final bool onChainWallet;
  final double amountBtc;
  final ReceiveAmountMethod method;
  final PaymentLink? initialPaymentLink;
  final ReceiveRequestStage? initialStage;
  final bool enableStatusPolling;
  final String? initialAddress;
  final String? initialPaymentUri;
  final String? initialTxid;
  final int? initialConfirmations;
  final int? requiredConfirmations;
  final DateTime? identifiedAt;

  /// When no [initialPaymentLink] is provided, the screen creates one using this TTL.
  final int paymentLinkExpiresInMinutes;

  /// When true, show network picker before any backend create call.
  final bool deferNetworkUntilChosen;

  const ReceiveRequestFlowScreen({
    super.key,
    required this.wallet,
    required this.onChainWallet,
    required this.amountBtc,
    required this.method,
    this.initialPaymentLink,
    this.initialStage,
    this.enableStatusPolling = true,
    this.initialAddress,
    this.initialPaymentUri,
    this.initialTxid,
    this.initialConfirmations,
    this.requiredConfirmations,
    this.identifiedAt,
    this.paymentLinkExpiresInMinutes = 60,
    this.deferNetworkUntilChosen = false,
  });

  @override
  ConsumerState<ReceiveRequestFlowScreen> createState() =>
      _ReceiveRequestFlowScreenState();
}

class _ReceiveRequestFlowScreenState
    extends ConsumerState<ReceiveRequestFlowScreen> with FinancialSurfaceMixin {
  Timer? _statusTimer;
  Timer? _expiryTicker;
  late ReceiveRequestStage _stage;
  late DateTime _identifiedAt;

  PaymentLink? _link;
  OnchainAddressAllocation? _allocation;
  ExternalTransfer? _observedTransfer;
  String? _address;
  String? _paymentUri;
  String? _txid;
  String? _errorMessage;
  bool _isLoadingRequest = false;
  bool _cancelling = false;
  bool _awaitingNetworkChoice = false;
  ReceiveNetworkChoice? _selectedNetwork;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage ?? ReceiveRequestStage.qr;
    _identifiedAt = widget.identifiedAt ?? DateTime.now();
    _link = widget.initialPaymentLink;
    _address = widget.initialAddress ?? _link?.depositAddress;
    _paymentUri = widget.initialPaymentUri ?? _paymentUriFor(_link);
    _txid = widget.initialTxid ?? _link?.txid;
    _awaitingNetworkChoice =
        widget.deferNetworkUntilChosen && widget.initialPaymentLink == null;

    if (widget.enableStatusPolling && !_awaitingNetworkChoice) {
      scheduleMicrotask(_prepareRequest);
    }
    // Cancelled links leave the global strip after the user opens them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final link = _link;
      if (link != null && (link.isCancelled || link.isExpired)) {
        unawaited(
          ref
              .read(activityArchiveProvider.notifier)
              .markArchived(paymentLinkArchiveId(link.id)),
        );
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _expiryTicker?.cancel();
    super.dispose();
  }

  void _startExpiryTicker() {
    _expiryTicker?.cancel();
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      final remaining = _remainingExpiry;
      if (remaining != null && remaining <= Duration.zero && _linkCanCancel) {
        // Keep UI reactive; expiry is owned by backend status.
      }
    });
  }

  Duration? get _remainingExpiry {
    final expiresAt = _link?.expiresAt;
    if (expiresAt == null) return null;
    return expiresAt.difference(DateTime.now());
  }

  Color get _expiryColor {
    final remaining = _remainingExpiry;
    final total = _link?.expiresAt == null
        ? null
        : _link!.expiresAt!.difference(
            _link!.createdAt ??
                _link!.expiresAt!.subtract(
                  Duration(minutes: widget.paymentLinkExpiresInMinutes),
                ),
          );
    if (remaining == null || total == null || total.inSeconds <= 0) {
      return _flowTokens().feedbackSuccess;
    }
    final ratio = remaining.inMilliseconds / total.inMilliseconds;
    // Green while above half; yellow around half; red below half.
    if (ratio > 0.52) return _flowTokens().feedbackSuccess;
    if (ratio >= 0.48) return _flowTokens().feedbackWarning;
    return _flowTokens().feedbackError;
  }

  String _formatRemaining(Duration? remaining) {
    if (remaining == null) return '--:--';
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final m = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = safe.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  List<ReceiveNetworkOption> _networkOptions() {
    // Best-value badge only for on-chain / cold receives (cost + time).
    if (widget.wallet.isColdWallet) {
      return const [
        ReceiveNetworkOption(
          choice: ReceiveNetworkChoice.onchain,
          title: 'On-chain',
          subtitle: 'Bitcoin L1 · menor atrito para carteira fria',
          timeLabel: '~30–60 min',
          confirmationLabel: '6 confirmações',
          bestValue: true,
        ),
      ];
    }
    return const [
      ReceiveNetworkOption(
        choice: ReceiveNetworkChoice.lightning,
        title: 'Lightning',
        subtitle: 'Menor custo e liquidação imediata',
        timeLabel: 'Imediato',
        confirmationLabel: 'Instantâneo',
        bestValue: true,
      ),
      ReceiveNetworkOption(
        choice: ReceiveNetworkChoice.onchain,
        title: 'On-chain',
        subtitle: 'Bitcoin L1 · confirmação em blocos',
        timeLabel: '~30–60 min',
        confirmationLabel: '6 confirmações',
      ),
    ];
  }

  void _onNetworkChosen(ReceiveNetworkChoice choice) {
    setState(() {
      _selectedNetwork = choice;
      _awaitingNetworkChoice = false;
    });
    unawaited(_prepareRequest());
  }

  Future<void> _prepareRequest() async {
    final link = _link;
    if (link != null) {
      _applyPaymentLinkStage(link);
      _startExpiryTicker();
      if (_stage == ReceiveRequestStage.identified) {
        return;
      }
      _startPaymentLinkPolling();
      return;
    }

    // Create shareable request on this screen (amount screen no longer blocks on it).
    final needsPaymentLink = widget.method == ReceiveAmountMethod.paymentLink ||
        widget.method == ReceiveAmountMethod.qrCode ||
        widget.method == ReceiveAmountMethod.nfc ||
        widget.method == ReceiveAmountMethod.p2p ||
        widget.method == ReceiveAmountMethod.lightning;
    if (needsPaymentLink) {
      await _createPaymentLinkOnScreen();
      return;
    }

    if (widget.onChainWallet) {
      await _issueOnchainAddress();
    }
  }

  String _paymentRequestRail() {
    if (_selectedNetwork == ReceiveNetworkChoice.lightning) {
      return 'LIGHTNING';
    }
    if (_selectedNetwork == ReceiveNetworkChoice.onchain) {
      return 'ONCHAIN';
    }
    switch (widget.method) {
      case ReceiveAmountMethod.p2p:
        return 'INTERNAL';
      case ReceiveAmountMethod.lightning:
        return 'LIGHTNING';
      case ReceiveAmountMethod.nfc:
        return widget.onChainWallet ? 'ONCHAIN' : 'INTERNAL';
      case ReceiveAmountMethod.qrCode:
      case ReceiveAmountMethod.paymentLink:
        // QR and payment-link receiving must be usable outside Kerosene too.
        // The backend issues a monitored receiving address for INTERNAL wallets
        // as well, so the shared payload can be a standard BIP-21 URI for both
        // Electrum and Kerosene. P2P remains the explicit INTERNAL rail.
        return 'ONCHAIN';
    }
  }

  Future<void> _createPaymentLinkOnScreen() async {
    setState(() {
      _isLoadingRequest = true;
      _errorMessage = null;
    });
    try {
      final paymentLink =
          await ref.read(transactionRepositoryProvider).createPaymentLink(
        amount: widget.amountBtc,
        description: ReceiveMoneyCopy.paymentLinkDescription(
          context,
          widget.wallet.name,
        ),
        expiresInMinutes: widget.paymentLinkExpiresInMinutes,
        visibility: 'PRIVATE',
        confirmationMode: 'USER_ACTION_REQUIRED',
        amountLocked: true,
        referenceLabel: widget.wallet.name,
        metadata: {
          'walletId': widget.wallet.id,
          'walletName': widget.wallet.name,
          'rail': _paymentRequestRail(),
          'method': widget.method.name,
          'source': 'receive_flow',
        },
      );
      if (!mounted) return;
      setState(() {
        _link = paymentLink;
        _address = paymentLink.depositAddress.trim().isEmpty
            ? _address
            : paymentLink.depositAddress.trim();
        _paymentUri = _paymentUriFor(paymentLink);
        _txid = paymentLink.txid;
        _isLoadingRequest = false;
        _applyPaymentLinkStage(paymentLink);
      });
      ref.invalidate(paymentLinksProvider);
      ref.invalidate(transactionHistoryProvider);
      _startExpiryTicker();
      if (_stage != ReceiveRequestStage.identified) {
        _startPaymentLinkPolling();
      }
    } catch (error) {
      if (!mounted) return;
      final translated = ErrorTranslator.translate(
        context.tr,
        error.toString(),
      );
      setState(() {
        _isLoadingRequest = false;
        _errorMessage = translated;
      });
      SnackbarHelper.showError(translated);
    }
  }

  Future<void> _issueOnchainAddress() async {
    setState(() {
      _isLoadingRequest = true;
      _errorMessage = null;
    });

    try {
      final allocation =
          await ref.read(transactionRepositoryProvider).issueOnchainAddress(
                walletName: widget.wallet.id,
                expectedAmountBtc: widget.amountBtc,
              );
      if (!mounted) return;

      final nextAddress = allocation.onchainAddress.trim();
      if (nextAddress.isEmpty || !allocation.hasTransferId) {
        setState(() {
          _isLoadingRequest = false;
          _errorMessage = ReceiveMoneyCopy.prepareTrackingFailed(context);
        });
        return;
      }

      setState(() {
        _allocation = allocation;
        _address = nextAddress;
        _paymentUri = QrPaymentParser.encode(
          address: nextAddress,
          amountBtc: widget.amountBtc,
          label: widget.wallet.name,
          message: context.tr.receiveKeroseneTitle,
        );
        _txid = allocation.blockchainTxid.trim().isEmpty
            ? null
            : allocation.blockchainTxid.trim();
        _isLoadingRequest = false;
        _stage = _stageForOnchain(
          status: allocation.transferStatus,
          confirmations: allocation.confirmations,
          txid: allocation.blockchainTxid,
        );
      });
      ref.invalidate(externalTransfersProvider);
      ref.invalidate(transactionHistoryProvider);
      _startTransferPolling();
    } catch (error) {
      if (!mounted) return;
      final translated = ErrorTranslator.translate(
        context.tr,
        error.toString(),
      );
      setState(() {
        _isLoadingRequest = false;
        _errorMessage = translated;
      });
      SnackbarHelper.showError(translated);
    }
  }

  void _startTransferPolling() {
    final transferId = _allocation?.transferId.trim() ?? '';
    if (transferId.isEmpty) return;
    _statusTimer?.cancel();
    // Immediate first refresh so detection does not wait a full poll period.
    unawaited(_refreshObservedTransfer());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshObservedTransfer(),
    );
  }

  Future<void> _refreshObservedTransfer() async {
    final transferId = _allocation?.transferId.trim() ?? '';
    if (transferId.isEmpty) return;

    try {
      final latest = await ref
          .read(transactionRepositoryProvider)
          .getExternalTransfer(transferId);
      if (!mounted) return;

      final previousStatus =
          (_observedTransfer?.status ?? _allocation?.transferStatus ?? '')
              .trim()
              .toUpperCase();
      final previousConfirmations =
          _observedTransfer?.confirmations ?? _allocation?.confirmations ?? 0;
      final latestStatus = latest.status.trim().toUpperCase();

      setState(() {
        _observedTransfer = latest;
        _txid = latest.blockchainTxid.trim().isEmpty
            ? _txid
            : latest.blockchainTxid.trim();
        _stage = _stageForOnchain(
          status: latest.status,
          confirmations: latest.confirmations,
          txid: latest.blockchainTxid,
        );
        if (_stage == ReceiveRequestStage.identified) {
          _identifiedAt = DateTime.now();
        }
      });

      if (previousStatus != latestStatus ||
          previousConfirmations != latest.confirmations) {
        ref.invalidate(externalTransfersProvider);
        ref.invalidate(transactionHistoryProvider);
      }

      if (_stage == ReceiveRequestStage.identified) {
        _statusTimer?.cancel();
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Keep the QR usable if the status refresh fails transiently.
    }
  }

  ReceiveRequestStage _stageForOnchain({
    required String status,
    required int confirmations,
    required String txid,
  }) {
    final normalized = status.trim().toUpperCase();
    final required = _requiredConfirmations;
    final complete = normalized == 'COMPLETED' ||
        normalized == 'SETTLED' ||
        (confirmations >= required &&
            (normalized == 'CONFIRMED' ||
                normalized == 'CREDITED' ||
                normalized == 'SETTLED'));
    if (complete) {
      return ReceiveRequestStage.identified;
    }
    if (txid.trim().isNotEmpty ||
        confirmations > 0 ||
        normalized == 'DETECTED' ||
        normalized == 'MEMPOOL' ||
        normalized == 'CONFIRMED') {
      return ReceiveRequestStage.confirmations;
    }
    return ReceiveRequestStage.qr;
  }

  void _startPaymentLinkPolling() {
    _statusTimer?.cancel();
    unawaited(_refreshPaymentLink());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshPaymentLink(),
    );
  }

  Future<void> _refreshPaymentLink() async {
    final linkId = _link?.id.trim() ?? '';
    if (linkId.isEmpty) return;

    try {
      final PaymentLink latest;
      latest =
          await ref.read(transactionRepositoryProvider).getPaymentLink(linkId);

      if (!mounted) return;
      final previousStatus = _link?.status.trim().toLowerCase() ?? '';
      final previousTxid = _link?.txid?.trim() ?? '';
      final latestStatus = latest.status.trim().toLowerCase();
      final latestTxid = latest.txid?.trim() ?? '';

      setState(() {
        _link = latest;
        _address = latest.depositAddress.trim().isEmpty
            ? _address
            : latest.depositAddress.trim();
        _paymentUri = _paymentUriFor(latest);
        _txid = latest.txid?.trim().isEmpty == true ? _txid : latest.txid;
        _applyPaymentLinkStage(latest);
      });

      if (previousStatus != latestStatus || previousTxid != latestTxid) {
        ref.invalidate(paymentLinksProvider);
        ref.invalidate(transactionHistoryProvider);
        if (_isOnChainReceive) {
          ref.invalidate(externalTransfersProvider);
        }
      }

      if (_stage == ReceiveRequestStage.identified) {
        _statusTimer?.cancel();
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Payment polling is intentionally quiet; the QR/link stays available.
    }
  }

  void _applyPaymentLinkStage(PaymentLink link) {
    final rail = link.paymentRail.trim().toUpperCase();
    final isLightning = link.isLightningPaymentRequest || rail == 'LIGHTNING';
    final onChain = !isLightning &&
        (widget.onChainWallet ||
            rail == 'ONCHAIN' ||
            looksLikeBitcoinAddress(link.depositAddress.trim()));
    final bolt11 = link.paymentRequest?.trim() ?? '';
    if (isLightning && bolt11.isNotEmpty) {
      _address = bolt11;
      // Multi-rail: if we also have an on-chain address, generate combined BIP-21.
      final hasChainDeposit = link.depositAddress.trim().isNotEmpty &&
          looksLikeBitcoinAddress(link.depositAddress.trim());
      if (hasChainDeposit) {
        _paymentUri = _paymentUriFor(link);
      } else {
        _paymentUri = bolt11;
      }
    } else {
      final uri = _paymentUriFor(link);
      if (uri != null && uri.isNotEmpty) {
        _paymentUri = uri;
      }
      final deposit = link.depositAddress.trim();
      if (deposit.isNotEmpty) {
        _address = deposit;
      }
    }
    // Lightning / internal: paid is done. On-chain: paid/detected opens conf rings;
    // "Confirmado" when confs meet the target or settlement is SETTLED — do not
    // require isPaid alone (normalize used to mask PAID while VALIDATING).
    final settlement = link.settlementStatus.trim().toUpperCase();
    final settledSettlement =
        settlement == 'SETTLED' || settlement == 'COMPLETED';
    final complete = link.isCompleted ||
        settledSettlement ||
        (isLightning && link.isPaid) ||
        (!onChain && !isLightning && link.isPaid) ||
        (onChain &&
            (link.confirmations >= _requiredConfirmations ||
                (link.isPaid && settledSettlement)));
    if (complete) {
      _stage = ReceiveRequestStage.identified;
      _identifiedAt = link.completedAt ?? link.paidAt ?? DateTime.now();
      return;
    }
    if (link.isPaid ||
        link.isVerifyingOnboarding ||
        link.confirmations > 0 ||
        link.hasObservedOnchainPayment ||
        settledSettlement ||
        settlement == 'VALIDATING' ||
        settlement == 'EXECUTING') {
      _stage = ReceiveRequestStage.confirmations;
      return;
    }
    _stage = ReceiveRequestStage.qr;
  }

  void _maybeAdvanceFromInboundHistory(List<Transaction> history) {
    if (_stage == ReceiveRequestStage.identified) return;
    final linkId = _link?.id.trim() ?? '';
    final address = _addressValue.trim().toLowerCase();
    final walletId = widget.wallet.id.trim().toLowerCase();
    final createdAt =
        _link?.createdAt ?? DateTime.now().subtract(const Duration(hours: 2));

    for (final tx in history) {
      if (!tx.isCredit) continue;
      final txCreated = tx.timestamp;
      if (txCreated.isBefore(createdAt.subtract(const Duration(minutes: 1)))) {
        continue;
      }
      final prId = tx.paymentRequestId?.trim() ?? '';
      final matchesLink = linkId.isNotEmpty &&
          (prId == linkId ||
              tx.id.contains(linkId) ||
              (tx.externalReference?.contains(linkId) ?? false));
      final toAddr = tx.toAddress.trim().toLowerCase();
      final matchesAddress = address.isNotEmpty &&
          looksLikeBitcoinAddress(address) &&
          (toAddr == address || toAddr.contains(address));
      final matchesWallet = walletId.isNotEmpty &&
          (tx.walletId?.trim().toLowerCase() == walletId ||
              tx.destinationWalletId?.trim().toLowerCase() == walletId);
      if (!matchesLink &&
          !matchesAddress &&
          !(matchesWallet && !_isOnChainReceive)) {
        continue;
      }

      final confs = tx.confirmations;
      setState(() {
        if (tx.blockchainTxid != null && tx.blockchainTxid!.trim().isNotEmpty) {
          _txid = tx.blockchainTxid!.trim();
        }
        if (_isOnChainReceive &&
            confs < _requiredConfirmations &&
            tx.status != TransactionStatus.confirmed) {
          _stage = ReceiveRequestStage.confirmations;
        } else {
          _stage = ReceiveRequestStage.identified;
          _identifiedAt = txCreated;
          _statusTimer?.cancel();
        }
      });
      if (_stage == ReceiveRequestStage.identified) {
        HapticFeedback.mediumImpact();
      }
      return;
    }
  }

  /// True when this receive surface should behave as on-chain (BIP-21 / confs).
  ///
  /// Uses the payment-request rail and the concrete deposit address, not only
  /// the wallet classification flag — INTERNAL ledger wallets can still issue
  /// testnet/mainnet deposit addresses.
  bool get _isOnChainReceive {
    if (_isLightningReceive) return false;
    if (widget.onChainWallet) return true;
    final rail = (_link?.paymentRail ?? '').trim().toUpperCase();
    if (rail == 'ONCHAIN') return true;
    final address = (_address ?? _link?.depositAddress ?? '').trim();
    if (address.toLowerCase().startsWith('ln')) return false;
    return address.isNotEmpty && looksLikeBitcoinAddress(address);
  }

  bool get _isLightningReceive {
    if (widget.method == ReceiveAmountMethod.lightning) return true;
    final link = _link;
    if (link != null && link.isLightningPaymentRequest) return true;
    final rail = (_link?.paymentRail ?? '').trim().toUpperCase();
    if (rail == 'LIGHTNING') return true;
    final payload = (_paymentUri ?? _address ?? '').trim().toLowerCase();
    return payload.startsWith('ln');
  }

  String? _paymentUriFor(PaymentLink? link) {
    if (link == null) return null;
    final bolt11 = link.paymentRequest?.trim();
    final deposit = link.depositAddress.trim();
    final hasBolt11 = bolt11 != null &&
        bolt11.isNotEmpty &&
        bolt11.toLowerCase().startsWith('ln');
    final hasChainAddress =
        deposit.isNotEmpty && looksLikeBitcoinAddress(deposit);

    // Multi-rail: BIP-21 with lightning= parameter so any wallet works.
    if (hasChainAddress && hasBolt11) {
      return QrPaymentParser.encode(
        address: deposit,
        amountBtc: link.amountBtc > 0 ? link.amountBtc : widget.amountBtc,
        label: widget.wallet.name,
        message: link.description,
        lightning: bolt11,
      );
    }

    // Lightning-only: QR must encode the BOLT11 invoice.
    if (link.isLightningPaymentRequest && hasBolt11) {
      return bolt11;
    }
    final shareable = link.shareablePaymentPayload;
    if (shareable.toLowerCase().startsWith('ln')) {
      return shareable;
    }

    // On-chain only: BIP-21.
    if (hasChainAddress) {
      return QrPaymentParser.encode(
        address: deposit,
        amountBtc: link.amountBtc > 0 ? link.amountBtc : widget.amountBtc,
        label: widget.wallet.name,
        message: link.description,
      );
    }

    final explicitUri = link.paymentUri?.trim();
    if (explicitUri != null && explicitUri.isNotEmpty) {
      final lower = explicitUri.toLowerCase();
      // Keep a backend-provided BIP-21 payload intact. It is the portable
      // contract shared by Electrum and Kerosene.
      if (lower.startsWith('bitcoin:') || lower.startsWith('web+bitcoin:')) {
        return explicitUri;
      }
      // Non-Bitcoin links are only valid for an explicitly non-on-chain rail
      // (for example a Kerosene internal payment request).
      if (!_isOnChainReceive) return explicitUri;
    }
    if (link.isInternalPaymentRequest || !_isOnChainReceive) {
      return QrPaymentParser.encodePaymentLink(link.id);
    }
    return null;
  }

  String get _addressValue {
    if (_isLightningReceive) {
      final bolt11 = (_link?.paymentRequest ??
              _paymentUri ??
              _address ??
              _link?.depositAddress ??
              '')
          .trim();
      if (bolt11.isNotEmpty) return bolt11;
    }
    final current = _address?.trim() ?? '';
    if (current.isNotEmpty &&
        !current.toLowerCase().startsWith('kerosene:') &&
        (looksLikeBitcoinAddress(current) || current.startsWith('bitcoin:'))) {
      if (current.toLowerCase().startsWith('bitcoin:')) {
        final parsed = QrPaymentParser.decode(current);
        final parsedAddress = parsed?.address.trim() ?? '';
        if (parsedAddress.isNotEmpty) return parsedAddress;
      }
      return current;
    }
    final linkAddress = _link?.depositAddress.trim() ?? '';
    if (linkAddress.isNotEmpty &&
        !linkAddress.toLowerCase().startsWith('kerosene:') &&
        looksLikeBitcoinAddress(linkAddress)) {
      return linkAddress;
    }
    final walletAddress = widget.wallet.address.trim();
    if (walletAddress.isNotEmpty && looksLikeBitcoinAddress(walletAddress)) {
      return walletAddress;
    }
    // Fall back to any non-empty display value last (internal refs, etc.).
    if (current.isNotEmpty) return current;
    if (linkAddress.isNotEmpty) return linkAddress;
    return walletAddress;
  }

  String get _paymentValue {
    final current = _paymentUri?.trim() ?? '';
    if (_isOnChainReceive) {
      final lower = current.toLowerCase();
      if (lower.startsWith('bitcoin:') || lower.startsWith('web+bitcoin:')) {
        return current;
      }
      // Never share an internal/web fallback as the payment payload for an
      // on-chain request. Electrum needs a BIP-21 URI (or the raw address).
      final address = _addressValue;
      if (address.isNotEmpty && looksLikeBitcoinAddress(address)) {
        return QrPaymentParser.encode(
          address: address,
          amountBtc: widget.amountBtc,
          label: widget.wallet.name,
          message: context.tr.receiveKeroseneTitle,
        );
      }
    }
    final link = _link;
    if (link != null) {
      final shareable = link.shareablePaymentPayload.trim();
      if (shareable.isNotEmpty) return shareable;
    }
    if (current.isNotEmpty) return current;
    if (_isLightningReceive) {
      final bolt11 = _addressValue;
      if (bolt11.toLowerCase().startsWith('ln')) return bolt11;
    }
    final address = _addressValue;
    if (address.isNotEmpty && looksLikeBitcoinAddress(address)) {
      return QrPaymentParser.encode(
        address: address,
        amountBtc: widget.amountBtc,
        label: widget.wallet.name,
        message: context.tr.receiveKeroseneTitle,
      );
    }
    if (_isOnChainReceive) {
      return QrPaymentParser.encode(
        address: address,
        amountBtc: widget.amountBtc,
        label: widget.wallet.name,
        message: context.tr.receiveKeroseneTitle,
      );
    }
    final linkId = _link?.id.trim() ?? '';
    if (linkId.isNotEmpty) {
      return QrPaymentParser.encodePaymentLink(linkId);
    }
    return QrPaymentParser.encodeKerosene(
      address: address,
      amountBtc: widget.amountBtc,
      label: widget.wallet.name,
    );
  }

  int get _requiredConfirmations {
    if (!_isOnChainReceive) return widget.requiredConfirmations ?? 1;
    return widget.requiredConfirmations ??
        _allocation?.requiredConfirmations ??
        3;
  }

  int get _currentConfirmations {
    if (!_isOnChainReceive) {
      if (_stage == ReceiveRequestStage.identified) {
        return _requiredConfirmations;
      }
      return widget.initialConfirmations ?? 0;
    }
    return _observedTransfer?.confirmations ??
        _allocation?.confirmations ??
        _link?.confirmations ??
        widget.initialConfirmations ??
        0;
  }

  String get _networkLabel {
    if (_isLightningReceive) return 'Lightning';
    if (!_isOnChainReceive) return 'Kerosene · interno';
    final fromAddress = bitcoinNetworkDisplayName(
      inferBitcoinNetworkFromAddress(_addressValue),
    );
    return switch (fromAddress) {
      'Testnet' => 'On-chain · Bitcoin Testnet',
      'Regtest' => 'On-chain · Bitcoin Regtest',
      'Mainnet' => 'On-chain · Bitcoin Mainnet',
      _ => () {
          final network = (_allocation?.network ?? '').trim().toLowerCase();
          return switch (network) {
            'testnet' ||
            'testnet4' ||
            'testnet3' =>
              'On-chain · Bitcoin Testnet',
            'regtest' => 'On-chain · Bitcoin Regtest',
            _ => 'On-chain · Bitcoin Mainnet',
          };
        }(),
    };
  }

  String get _statusLabel {
    if (_isLightningReceive) {
      return ReceiveMoneyCopy.lightningSettledStatus(context);
    }
    if (_isOnChainReceive) return 'Confirmado na rede';
    return 'Confirmado na Kerosene';
  }

  String get _amountLabel {
    final received = _link?.amountBtc ??
        _observedTransfer?.amountBtc ??
        _allocation?.expectedAmountBtc;
    final btc =
        (received != null && received > 0) ? received : widget.amountBtc;
    final amount = MoneyDisplay.formatCompact(
      amount: btc,
      currency: Currency.btc,
      withSymbol: false,
      maxDecimalPlaces: 8,
    );
    return '$amount BTC';
  }

  String get _requestedAmountLabel {
    final received = _link?.amountBtc;
    final btc =
        (received != null && received > 0) ? received : widget.amountBtc;
    final amount = MoneyDisplay.format(
      amount: btc,
      currency: Currency.btc,
      withSymbol: false,
      decimalPlaces: 6,
    );
    return '$amount BTC';
  }

  String get _monitorStatusLabel {
    if (_stage == ReceiveRequestStage.identified) {
      if (_isLightningReceive) {
        return ReceiveMoneyCopy.lightningSettledStatus(context);
      }
      return _isOnChainReceive ? 'Confirmado' : 'Recebido';
    }
    if (_stage == ReceiveRequestStage.confirmations) {
      if (_isLightningReceive) {
        return ReceiveMoneyCopy.lightningPendingStatus(context);
      }
      if (_link?.isValidatingSettlement == true) {
        return 'Validando ${_currentConfirmations.clamp(0, _requiredConfirmations)}/$_requiredConfirmations confirmações';
      }
      return '${_currentConfirmations.clamp(0, _requiredConfirmations)}/$_requiredConfirmations confirmações';
    }
    if (_isLightningReceive) {
      return ReceiveMoneyCopy.lightningPendingStatus(context);
    }
    return 'Pendente';
  }

  String get _receiveFlowTitle {
    if (_isLightningReceive) {
      return ReceiveMoneyCopy.receiveLightningTitle(context);
    }
    if (_isOnChainReceive) {
      return ReceiveMoneyCopy.receiveBitcoinTitle(context);
    }
    return ReceiveMoneyCopy.receiveKeroseneTitle(context);
  }

  String get _fiatLabel {
    final money = ref.watch(moneyFormatConfigProvider);
    final fiat = money.currency == Currency.btc ? Currency.usd : money.currency;
    final received = _link?.amountBtc ??
        _observedTransfer?.amountBtc ??
        _allocation?.expectedAmountBtc;
    final btc =
        (received != null && received > 0) ? received : widget.amountBtc;
    return '≈ ${money.formatAmountFromBtc(btcAmount: btc, currency: fiat, btcUsd: ref.watch(latestBtcPriceProvider), btcEur: ref.watch(btcEurPriceProvider), btcBrl: ref.watch(btcBrlPriceProvider))}';
  }

  Future<void> _copyPaymentValue() async {
    final successMessage = context.tr.receiveQrCopied;
    await Clipboard.setData(ClipboardData(text: _paymentValue));
    await HapticFeedback.selectionClick();
    SnackbarHelper.showSuccess(successMessage);
  }

  Future<void> _sharePaymentValue() async {
    final payload = _paymentValue.trim();
    if (payload.isEmpty) return;
    final subject = ReceiveMoneyCopy.hubTitle(context);
    await HapticFeedback.selectionClick();
    await SharePlus.instance.share(
      ShareParams(text: payload, subject: subject),
    );
  }

  bool get _linkCanCancel {
    final link = _link;
    if (link == null || _cancelling) return false;
    return link.isPending &&
        !link.isCancelled &&
        !link.isExpired &&
        !link.isPaid;
  }

  Future<void> _confirmAndCancelPaymentLink() async {
    final link = _link;
    if (link == null || !_linkCanCancel) return;
    final tr = context.tr;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _flowTokens().surfaceHigh,
        title: Text(
          tr.receivePaymentLinkCancelTitle,
          style: AppTypography.inter(
            color: _flowTokens().textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          tr.receivePaymentLinkCancelMessage,
          style: AppTypography.inter(
            color: _flowTokens().textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(tr.receivePaymentLinkConfirmCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final updated = await ref
          .read(transactionRepositoryProvider)
          .cancelPaymentRequest(link.id);
      _statusTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _link = updated;
        _cancelling = false;
      });
      ref.invalidate(paymentLinksProvider);
      ref.invalidate(transactionHistoryProvider);
      SnackbarHelper.showSuccess(tr.receivePaymentLinkCancelled);
    } catch (error) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      SnackbarHelper.showError(
        ErrorTranslator.translate(context.tr, error.toString()),
      );
    }
  }

  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // When an inbound lands for this payment request / address, leave the QR
    // even if the payment-link poll lags one cycle.
    ref.listen<AsyncValue<List<Transaction>>>(transactionHistoryProvider, (
      previous,
      next,
    ) {
      next.whenData(_maybeAdvanceFromInboundHistory);
    });

    final Widget child;
    if (_awaitingNetworkChoice) {
      child = Column(
        key: const ValueKey('receive-network'),
        children: [
          Expanded(
            child: ReceiveNetworkPicker(
              options: _networkOptions(),
              onSelected: _onNetworkChosen,
              onBack: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
    } else {
      child = switch (_stage) {
        ReceiveRequestStage.qr => _buildQrScreen(context),
        ReceiveRequestStage.confirmations => _buildConfirmationsScreen(context),
        ReceiveRequestStage.identified => _buildIdentifiedScreen(context),
      };
    }

    return Scaffold(
      backgroundColor: _receiveBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: context.responsive.appColumnConstraints,
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: KeroseneMotion.medium,
                  switchInCurve: KeroseneMotion.standard,
                  switchOutCurve: KeroseneMotion.exit,
                  child: KeyedSubtree(
                    key: ValueKey(
                      _awaitingNetworkChoice ? 'network' : _stage.name,
                    ),
                    child: child,
                  ),
                ),
                if (_isLoadingRequest) const ReceiveLoadingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrScreen(BuildContext context) {
    return Column(
      children: [
        _buildQrTopBar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              ReceiveFlowLayout.pageHorizontal,
              ReceiveFlowLayout.titleToContentGap,
              ReceiveFlowLayout.pageHorizontal,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ReceiveMoneyCopy.pointCameraHint(context),
                  textAlign: TextAlign.left,
                  style: AppTypography.captionLarge.copyWith(
                    color: _receiveMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Center(child: _buildQrBox(size: 220)),
                const SizedBox(height: 18),
                Center(child: _buildQrAmount(context)),
                const SizedBox(height: 14),
                _buildReceiveDetails(context),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  InlineNotice(message: _errorMessage!),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ReceiveFlowLayout.pageHorizontal,
            8,
            ReceiveFlowLayout.pageHorizontal,
            ReceiveFlowLayout.pageBottom + 4,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ReceiveActionButton(
              icon: KeroseneIcons.share,
              label: context.tr.share,
              primary: true,
              onTap: _sharePaymentValue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrTopBar(BuildContext context) {
    final remaining = _remainingExpiry;
    final canCancel = _linkCanCancel;
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(KeroseneIcons.back, size: 20),
              color: _receiveText,
              style: IconButton.styleFrom(shape: const CircleBorder()),
            ),
            const Spacer(),
            if (_link?.expiresAt != null) ...[
              Text(
                _formatRemaining(remaining),
                style: AppTypography.ibmPlexMono(
                  color: _expiryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
            ],
            IconButton(
              onPressed: canCancel
                  ? (_cancelling ? null : _confirmAndCancelPaymentLink)
                  : () => Navigator.of(context).maybePop(),
              icon: _cancelling
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _expiryColor,
                      ),
                    )
                  : Icon(KeroseneIcons.close, size: 18, color: _expiryColor),
              style: IconButton.styleFrom(shape: const CircleBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveDetails(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: _flowTokens().surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          DetailRow(
            label: context.tr.sendReviewWallet,
            value: widget.wallet.name,
          ),
          const ReceiveDivider(),
          DetailRow(
            label: ReceiveMoneyCopy.detailNetwork(context),
            value: _networkLabel,
          ),
          const ReceiveDivider(),
          DetailRow(
            label: ReceiveMoneyCopy.detailRequested(context),
            value: _requestedAmountLabel,
          ),
          const ReceiveDivider(),
          _buildAddressPill(context),
        ],
      ),
    );
  }

  Widget _buildAddressPill(BuildContext context) {
    final label = _isLightningReceive
        ? ReceiveMoneyCopy.detailInvoice(context)
        : ReceiveMoneyCopy.detailAddress(context);
    final display = _isLightningReceive
        ? shortenReceiveAddress(_addressValue, head: 12, tail: 8)
        : shortenReceiveAddress(_addressValue, head: 10, tail: 6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.captionLarge.copyWith(
              color: _receiveMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              key: const ValueKey('receive-address-pill-copy'),
              onTap: _copyRawAddress,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        display,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTypography.ibmPlexMono(
                          color: _receiveText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(KeroseneIcons.copy, size: 18, color: _receiveMuted),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyRawAddress() async {
    final payload = _isLightningReceive ? _paymentValue : _addressValue;
    await Clipboard.setData(ClipboardData(text: payload));
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    SnackbarHelper.showSuccess(
      _isLightningReceive
          ? ReceiveMoneyCopy.invoiceCopied(context)
          : ReceiveMoneyCopy.addressCopied(context),
    );
  }

  Widget _buildConfirmationsScreen(BuildContext context) {
    final receiveTitle = _receiveFlowTitle;
    return Column(
      children: [
        ReceiveContextHeader(
          title: _monitorStatusLabel,
          icon: KeroseneIcons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              ReceiveFlowLayout.pageHorizontal,
              ReceiveFlowLayout.optionGap,
              ReceiveFlowLayout.pageHorizontal,
              18,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  receiveTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.h1.copyWith(
                    color: _receiveText,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                _buildQrBox(size: 180),
                const SizedBox(height: 16),
                _buildQrAmount(context),
                const SizedBox(height: 16),
                _buildReceiveDetails(context),
                const SizedBox(height: 16),
                ReceiveNetworkStatusRow(
                  onChainWallet: _isOnChainReceive,
                  lightning: _isLightningReceive,
                  identified: _stage == ReceiveRequestStage.identified,
                  currentConfirmations: _currentConfirmations
                      .clamp(0, _requiredConfirmations)
                      .toInt(),
                  requiredConfirmations: _requiredConfirmations,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ReceiveActionButton(
                        icon: KeroseneIcons.copy,
                        label: context.tr.copy,
                        onTap: _copyPaymentValue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ReceiveActionButton(
                        icon: KeroseneIcons.share,
                        label: context.tr.share,
                        primary: true,
                        onTap: _sharePaymentValue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentifiedScreen(BuildContext context) {
    final identifiedLabel = ReceiveMoneyCopy.paymentIdentifiedTitle(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              ReceiveFlowLayout.pageHorizontal,
              ReceiveFlowLayout.titleToContentGap + 4,
              ReceiveFlowLayout.pageHorizontal,
              ReceiveFlowLayout.pageBottom,
            ),
            child: MovementConfirmationSurface(
              leading: ReceiveSuccessGraphic(
                animation: const AlwaysStoppedAnimation(1),
              ),
              title: identifiedLabel,
              amountLabel: _amountLabel,
              supportingLabel: _fiatLabel,
              rows: [
                MovementConfirmationRow(
                  label: context.tr.sendReviewStatus,
                  value: _statusLabel,
                ),
                MovementConfirmationRow(
                  label: context.tr.sendReviewDestination,
                  value: shortenReceiveAddress(_addressValue),
                  technical: true,
                ),
                MovementConfirmationRow(
                  label: ReceiveMoneyCopy.detailNetwork(context),
                  value: _networkLabel,
                ),
                MovementConfirmationRow(
                  label: ReceiveMoneyCopy.detailDate(context),
                  value: formatReceiveDateTime(_identifiedAt),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ReceiveFlowLayout.pageHorizontal,
            8,
            ReceiveFlowLayout.pageHorizontal,
            ReceiveFlowLayout.pageBottom + 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _goHome,
                  style: FilledButton.styleFrom(
                    backgroundColor: _flowTokens().ctaBackground,
                    foregroundColor: _flowTokens().ctaForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: AppTypography.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  child: Text(ReceiveMoneyCopy.doneAction(context)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _sharePaymentValue,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _flowTokens().textPrimary,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(KeroseneIcons.share, size: 17),
                  label: Text(context.tr.share),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrBox({required double size}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: KeroseneMotion.reduceMotion(context) ? 1.0 : 0.985,
        end: 1,
      ),
      duration: KeroseneMotion.duration(context, KeroseneMotion.statusChange),
      curve: KeroseneMotion.standard,
      builder: (context, scale, child) {
        final t = ((scale - 0.985) / 0.015).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: QrImageView(
          data: _paymentValue.isEmpty ? ' ' : _paymentValue,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
          // QR center mark requires a raster ImageProvider; K brand mark is
          // Lottie-only (`kerosene-k-logo.json`), so no embedded logo here.
        ),
      ),
    );
  }

  Widget _buildQrAmount(BuildContext context) {
    return Text(
      _amountLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTypography.amountInput(
        isBtc: true,
        color: _receiveText,
      ).copyWith(fontSize: 26, height: 1.12, letterSpacing: 0),
    );
  }
}
