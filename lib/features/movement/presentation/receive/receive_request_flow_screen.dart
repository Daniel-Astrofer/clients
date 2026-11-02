import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icon.dart';
import 'package:kerosene/features/movement/presentation/shared/movement_money.dart';
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
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/domain/entities/external_transfer.dart';
import 'package:kerosene/features/movement/domain/entities/onchain_address_allocation.dart';
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
import 'receive_bitcoin_network.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;

enum ReceiveRequestStage { qr, confirmations, identified, closed }

final receiveRequestShareProvider =
    Provider<Future<ShareResult> Function(ShareParams)>(
        (ref) => SharePlus.instance.share);

SendFlowTheme _flowTokens(BuildContext context) =>
    SendFlowTheme.forVariant(Theme.of(context).brightness);

class ReceiveRequestFlowScreen extends ConsumerStatefulWidget {
  final Wallet wallet;
  final bool onChainWallet;
  final double amountBtc;
  final MovementMoney? money;
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
  final String? ownerScope;

  /// When no [initialPaymentLink] is provided, the screen creates one using this TTL.
  final int paymentLinkExpiresInMinutes;

  /// When true, show network picker before any backend create call.
  final bool deferNetworkUntilChosen;

  const ReceiveRequestFlowScreen({
    super.key,
    required this.wallet,
    required this.onChainWallet,
    required this.amountBtc,
    this.money,
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
    this.ownerScope,
    this.paymentLinkExpiresInMinutes = 60,
    this.deferNetworkUntilChosen = false,
  });

  @override
  ConsumerState<ReceiveRequestFlowScreen> createState() =>
      _ReceiveRequestFlowScreenState();
}

class _ReceiveRequestFlowScreenState
    extends ConsumerState<ReceiveRequestFlowScreen>
    with FinancialSurfaceMixin, WidgetsBindingObserver {
  Color get _receiveBackground => _flowTokens(context).background;
  Color get _receiveText => _flowTokens(context).textPrimary;
  Color get _receiveMuted => _flowTokens(context).textMuted;

  Timer? _statusTimer;
  Timer? _expiryTicker;
  late ReceiveRequestStage _stage;
  DateTime? _identifiedAt;
  String get _receiptDateLabel => _identifiedAt == null
      ? context.tr.receiveReceiptDateUnavailable
      : formatReceiveDateTime(_identifiedAt!, context: context);

  PaymentLink? _link;
  OnchainAddressAllocation? _allocation;
  ExternalTransfer? _observedTransfer;
  Transaction? _historyReceipt;
  String? _address;
  String? _paymentUri;
  String? _txid;
  String? _errorMessage;
  bool _isLoadingRequest = false;
  bool _cancelling = false;
  bool _awaitingNetworkChoice = false;
  bool _statusRefreshBusy = false;
  bool _foreground = true;
  bool _statusUnavailable = false;
  bool _presentationBusy = false;
  bool _scopeLost = false;
  bool _cancelDialogOpen = false;
  bool _cancelNeedsRefresh = false;
  late final String? _ownerScope;

  bool get _owns =>
      mounted &&
      !_scopeLost &&
      ref.read(sessionStorageScopeProvider)?.trim() == _ownerScope;
  bool get _canAct => _owns && _foreground;
  int _linkRevision = 0;
  ReceiveNetworkChoice? _selectedNetwork;

  @override
  void initState() {
    super.initState();
    _ownerScope = widget.ownerScope?.trim() ??
        ref.read(sessionStorageScopeProvider)?.trim();
    _scopeLost = ref.read(sessionStorageScopeProvider)?.trim() != _ownerScope;
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _stage = widget.initialStage ?? ReceiveRequestStage.qr;
    _identifiedAt = widget.identifiedAt;
    _link = widget.initialPaymentLink;
    _address = widget.initialAddress ?? _link?.depositAddress;
    _paymentUri = widget.initialPaymentUri ?? _paymentUriFor(_link);
    _txid = widget.initialTxid ?? _link?.txid;
    _awaitingNetworkChoice =
        widget.deferNetworkUntilChosen && widget.initialPaymentLink == null;
    if (_link != null && widget.initialStage == null) {
      _applyPaymentLinkStage(_link!);
    }

    if (widget.enableStatusPolling && !_awaitingNetworkChoice) {
      scheduleMicrotask(_prepareRequest);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _expiryTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _foreground = state == AppLifecycleState.resumed);
    if (!_foreground) {
      _statusTimer?.cancel();
      _expiryTicker?.cancel();
    } else if (widget.enableStatusPolling &&
        _owns &&
        !_awaitingNetworkChoice &&
        _stage != ReceiveRequestStage.identified) {
      if (_link != null) {
        _startPaymentLinkPolling();
        _startExpiryTicker();
      } else if (_allocation != null) {
        _startTransferPolling();
      }
    }
  }

  void _startExpiryTicker() {
    _expiryTicker?.cancel();
    if (!_canAct ||
        _link?.expiresAt == null ||
        _stage == ReceiveRequestStage.identified ||
        _stage == ReceiveRequestStage.closed) {
      return;
    }
    _expiryTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_canAct) return;
      setState(() {
        if (_link != null) _applyPaymentLinkStage(_link!);
      });
      if (_remainingExpiry != null && _remainingExpiry! <= Duration.zero) {
        _expiryTicker?.cancel();
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
      return _flowTokens(context).feedbackSuccess;
    }
    final ratio = remaining.inMilliseconds / total.inMilliseconds;
    // Green while above half; yellow around half; red below half.
    if (ratio > 0.52) return _flowTokens(context).feedbackSuccess;
    if (ratio >= 0.48) return _flowTokens(context).feedbackWarning;
    return _flowTokens(context).feedbackError;
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
    if (!_canAct || !_awaitingNetworkChoice) return;
    setState(() {
      _selectedNetwork = choice;
      _awaitingNetworkChoice = false;
    });
    unawaited(_prepareRequest());
  }

  Future<void> _prepareRequest() async {
    if (!_canAct || _isLoadingRequest) return;
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
    if (!_canAct || _isLoadingRequest) return;
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
      if (!mounted || !_owns) return;
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
      if (!mounted || !_owns) return;
      final translated = ErrorTranslator.translate(
        context.tr,
        error.toString(),
      );
      setState(() {
        _isLoadingRequest = false;
        _errorMessage = translated;
      });
      if (_canAct) SnackbarHelper.showError(translated);
    }
  }

  Future<void> _issueOnchainAddress() async {
    if (!_canAct || _isLoadingRequest) return;
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
      if (!mounted || !_owns) return;

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
      if (!mounted || !_owns) return;
      final translated = ErrorTranslator.translate(
        context.tr,
        error.toString(),
      );
      setState(() {
        _isLoadingRequest = false;
        _errorMessage = translated;
      });
      if (_canAct) SnackbarHelper.showError(translated);
    }
  }

  void _startTransferPolling() {
    if (!_canAct ||
        _stage == ReceiveRequestStage.closed ||
        _stage == ReceiveRequestStage.identified) {
      return;
    }
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
    if (_statusRefreshBusy || !_canAct) return;
    final transferId = _allocation?.transferId.trim() ?? '';
    if (transferId.isEmpty) return;
    _statusRefreshBusy = true;

    try {
      final latest = await ref
          .read(transactionRepositoryProvider)
          .getExternalTransfer(transferId);
      if (!mounted || !_owns) return;
      if (_allocation?.transferId != transferId) return;
      if (latest.id != transferId) {
        setState(() => _statusUnavailable = true);
        return;
      }

      final previousStatus =
          (_observedTransfer?.status ?? _allocation?.transferStatus ?? '')
              .trim()
              .toUpperCase();
      final previousConfirmations =
          _observedTransfer?.confirmations ?? _allocation?.confirmations ?? 0;
      final latestStatus = latest.status.trim().toUpperCase();

      setState(() {
        _statusUnavailable = false;
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
          _identifiedAt = latest.settledAt ?? widget.identifiedAt;
        }
      });

      if (previousStatus != latestStatus ||
          previousConfirmations != latest.confirmations) {
        ref.invalidate(externalTransfersProvider);
        ref.invalidate(transactionHistoryProvider);
      }

      if (_stage == ReceiveRequestStage.identified ||
          _stage == ReceiveRequestStage.closed) {
        _statusTimer?.cancel();
        _expiryTicker?.cancel();
        if (_canAct && _stage == ReceiveRequestStage.identified) {
          HapticFeedback.mediumImpact();
        }
      }
    } catch (_) {
      if (_owns) setState(() => _statusUnavailable = true);
    } finally {
      _statusRefreshBusy = false;
    }
  }

  ReceiveRequestStage _stageForOnchain({
    required String status,
    required int confirmations,
    required String txid,
  }) {
    final normalized = status.trim().toUpperCase();
    if (const ['FAILED', 'CANCELLED', 'CANCELED', 'EXPIRED']
        .contains(normalized)) {
      return ReceiveRequestStage.closed;
    }
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
    if (!_canAct ||
        (_stage == ReceiveRequestStage.identified && !_cancelNeedsRefresh) ||
        _stage == ReceiveRequestStage.closed) {
      return;
    }
    unawaited(_refreshPaymentLink());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshPaymentLink(),
    );
  }

  Future<void> _refreshPaymentLink() async {
    if (_statusRefreshBusy || !_canAct) return;
    final linkId = _link?.id.trim() ?? '';
    if (linkId.isEmpty || _cancelling) return;
    final revision = _linkRevision;
    _statusRefreshBusy = true;

    try {
      final PaymentLink latest;
      latest =
          await ref.read(transactionRepositoryProvider).getPaymentLink(linkId);

      if (!mounted || !_owns) return;
      if (_link?.id != linkId || revision != _linkRevision) return;
      if (latest.id != linkId) {
        setState(() => _statusUnavailable = true);
        return;
      }
      final previousStatus = _link?.status.trim().toLowerCase() ?? '';
      final previousTxid = _link?.txid?.trim() ?? '';
      final latestStatus = latest.status.trim().toLowerCase();
      final latestTxid = latest.txid?.trim() ?? '';

      setState(() {
        _statusUnavailable = false;
        _link = latest;
        _cancelNeedsRefresh = false;
        final confirmedReceipt =
            _historyReceipt?.status == TransactionStatus.confirmed;
        if (!confirmedReceipt) {
          _historyReceipt = null;
        }
        _address = latest.depositAddress.trim().isEmpty
            ? _address
            : latest.depositAddress.trim();
        _paymentUri = _paymentUriFor(latest);
        _txid = latest.txid?.trim().isEmpty == true ? _txid : latest.txid;
        if (!confirmedReceipt) {
          _applyPaymentLinkStage(latest);
        }
      });

      if (previousStatus != latestStatus || previousTxid != latestTxid) {
        ref.invalidate(paymentLinksProvider);
        ref.invalidate(transactionHistoryProvider);
        if (_isOnChainReceive) {
          ref.invalidate(externalTransfersProvider);
        }
      }

      if (_stage == ReceiveRequestStage.identified ||
          _stage == ReceiveRequestStage.closed) {
        _statusTimer?.cancel();
        _expiryTicker?.cancel();
        if (_canAct && _stage == ReceiveRequestStage.identified) {
          HapticFeedback.mediumImpact();
        }
      }
    } catch (_) {
      if (_owns) setState(() => _statusUnavailable = true);
    } finally {
      _statusRefreshBusy = false;
    }
  }

  void _applyPaymentLinkStage(PaymentLink link) {
    final isLightning = link.isLightningPaymentRequest;
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
    final settlement = link.settlementStatus.trim().toUpperCase();
    final complete = link.isSettled;
    if (!complete &&
        (link.isCancelled ||
            link.isFailed ||
            (link.isExpired && !link.hasObservedOnchainPayment))) {
      _stage = ReceiveRequestStage.closed;
      _expiryTicker?.cancel();
      return;
    }
    if (complete) {
      _stage = ReceiveRequestStage.identified;
      _identifiedAt = link.completedAt ?? link.paidAt ?? widget.identifiedAt;
      return;
    }
    if (link.isPaid ||
        link.isVerifyingOnboarding ||
        link.confirmations > 0 ||
        link.hasObservedOnchainPayment ||
        settlement == 'VALIDATING' ||
        settlement == 'EXECUTING') {
      _stage = ReceiveRequestStage.confirmations;
      return;
    }
    _stage = ReceiveRequestStage.qr;
  }

  void _maybeAdvanceFromInboundHistory(List<Transaction> history) {
    if (!mounted || !_owns) return;
    if (_stage == ReceiveRequestStage.identified) return;
    final linkId = _link?.id.trim() ?? '';
    final address = _addressValue.trim().toLowerCase();
    final walletId = widget.wallet.id.trim().toLowerCase();
    final createdAt =
        _link?.createdAt ?? DateTime.now().subtract(const Duration(hours: 2));

    for (final tx in history) {
      if (!tx.isCredit ||
          tx.status == TransactionStatus.failed ||
          tx.status == TransactionStatus.cancelled) {
        continue;
      }
      if (tx.status == TransactionStatus.pending &&
          tx.cancellable &&
          tx.cancelTarget == 'PAYMENT_REQUEST') {
        continue;
      }
      final txCreated = tx.timestamp;
      if (txCreated.isBefore(createdAt.subtract(const Duration(minutes: 1)))) {
        continue;
      }
      final prId = tx.paymentRequestId?.trim() ?? '';
      final matchesLink =
          linkId.isNotEmpty && (prId == linkId || tx.id == 'pl_$linkId');
      if (linkId.isNotEmpty && prId.isNotEmpty && prId != linkId) continue;
      final toAddr = tx.toAddress.trim().toLowerCase();
      final matchesAddress = address.isNotEmpty &&
          looksLikeBitcoinAddress(address) &&
          toAddr == address;
      final matchesWallet = walletId.isNotEmpty &&
          (tx.walletId?.trim().toLowerCase() == walletId ||
              tx.destinationWalletId?.trim().toLowerCase() == walletId);
      if (!matchesLink &&
          !matchesAddress &&
          !(matchesWallet && linkId.isEmpty && !_isOnChainReceive)) {
        continue;
      }

      setState(() {
        _historyReceipt = tx;
        if (tx.blockchainTxid != null && tx.blockchainTxid!.trim().isNotEmpty) {
          _txid = tx.blockchainTxid!.trim();
        }
        if (tx.status != TransactionStatus.confirmed) {
          _stage = ReceiveRequestStage.confirmations;
        } else {
          _stage = ReceiveRequestStage.identified;
          _identifiedAt = txCreated;
          _linkRevision++;
          _statusTimer?.cancel();
          _expiryTicker?.cancel();
        }
      });
      if (_canAct && _stage == ReceiveRequestStage.identified) {
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
    return _historyReceipt?.confirmations ??
        _observedTransfer?.confirmations ??
        _allocation?.confirmations ??
        _link?.confirmations ??
        widget.initialConfirmations ??
        0;
  }

  String get _networkLabel {
    if (_isLightningReceive) return context.tr.activityFilterLightning;
    if (!_isOnChainReceive) return context.tr.activityFilterInternal;
    final network = switch (resolveReceiveBitcoinNetwork(
        network: _allocation?.network, address: _addressValue)) {
      ReceiveBitcoinNetwork.mainnet => 'Mainnet',
      ReceiveBitcoinNetwork.testnet => 'Testnet',
      ReceiveBitcoinNetwork.testnet3 => 'Testnet3',
      ReceiveBitcoinNetwork.testnet4 => 'Testnet4',
      ReceiveBitcoinNetwork.signet => 'Signet',
      ReceiveBitcoinNetwork.regtest => 'Regtest',
      ReceiveBitcoinNetwork.testFamily => context.tr.receiveNetworkTestFamily,
      ReceiveBitcoinNetwork.unknown => context.tr.receiveNetworkUnknown,
    };
    return '${context.tr.activityFilterOnchain} · $network';
  }

  String get _statusLabel {
    if (_isLightningReceive) {
      return ReceiveMoneyCopy.lightningSettledStatus(context);
    }
    if (_isOnChainReceive) return 'Confirmado na rede';
    return 'Confirmado na Kerosene';
  }

  double get _displayAmountBtc {
    if (_stage == ReceiveRequestStage.identified && _historyReceipt != null) {
      return _historyReceipt!.amountSatoshis / 100000000.0;
    }
    if (_stage == ReceiveRequestStage.identified &&
        _link?.hasNetAmount == true) {
      return _link!.netAmountBtc;
    }
    final received = _link?.amountBtc ??
        _observedTransfer?.amountBtc ??
        _allocation?.expectedAmountBtc;
    return received != null && received > 0 ? received : widget.amountBtc;
  }

  String get _amountLabel {
    final money = widget.money ?? const MovementMoney();
    final sats = _stage == ReceiveRequestStage.identified
        ? _historyReceipt?.amountSatoshis ??
            (_link?.hasNetAmount == true
                ? _link?.netAmountSatoshis
                : _link?.amountSatoshis)
        : _link?.amountSatoshis;
    return sats != null
        ? money.primarySatoshis(sats)
        : money.primary(_displayAmountBtc);
  }

  String get _requestedAmountLabel =>
      (widget.money ?? const MovementMoney()).primary(widget.amountBtc);

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
      if (_isOnChainReceive &&
          _currentConfirmations >= _requiredConfirmations) {
        return context.tr.receiveCreditValidating;
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
    if (widget.money != null) {
      return widget.money!.secondary(_displayAmountBtc);
    }
    return '';
  }

  bool get _canShareRequest =>
      _stage == ReceiveRequestStage.identified ||
      (_stage != ReceiveRequestStage.closed &&
          !(_link?.isExpired ?? false) &&
          !(_link?.isCancelled ?? false) &&
          !(_link?.isFailed ?? false));

  Future<void> _copyPaymentValue() async {
    if (!_canShareRequest || _stage == ReceiveRequestStage.identified) return;
    await _copyPayload(_paymentValue, context.tr.receiveQrCopied);
  }

  Future<void> _sharePaymentValue() async {
    if (!_canAct || _presentationBusy || !_canShareRequest) return;
    final payload = _stage == ReceiveRequestStage.identified
        ? [
            context.tr.receiveReceiptShareTitle,
            _amountLabel,
            '${context.tr.sendReviewStatus}: $_statusLabel',
            '${ReceiveMoneyCopy.detailDate(context)}: $_receiptDateLabel',
            if (_historyReceipt != null)
              '${context.tr.receiveReceiptOperationId}: ${_historyReceipt!.id}',
            if (_link != null)
              '${context.tr.receiveReceiptRequestId}: ${_link!.id}',
            if (_txid?.trim().isNotEmpty == true) 'TXID: $_txid',
            if (_addressValue.isNotEmpty)
              '${ReceiveMoneyCopy.detailAddress(context)}: $_addressValue',
          ].join('\n')
        : _paymentValue.trim();
    if (payload.isEmpty) return;
    final stage = _stage;
    final subject = _stage == ReceiveRequestStage.identified
        ? context.tr.receiveReceiptShareTitle
        : ReceiveMoneyCopy.hubTitle(context);
    final tr = context.tr;
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() => _presentationBusy = true);
    try {
      final result = await ref.read(receiveRequestShareProvider)(ShareParams(
          text: payload, subject: subject, sharePositionOrigin: origin));
      if (!_canAct || _stage != stage) return;
      switch (result.status) {
        case ShareResultStatus.success:
          SnackbarHelper.showSuccess(tr.receiveShareCompleted);
        case ShareResultStatus.dismissed:
          break;
        case ShareResultStatus.unavailable:
          SnackbarHelper.showInfo(tr.receiveShareUnconfirmed);
      }
    } catch (_) {
      if (_canAct && _stage == stage) {
        SnackbarHelper.showError(tr.receiveShareFailed);
      }
    } finally {
      if (mounted) setState(() => _presentationBusy = false);
    }
  }

  bool get _linkCanCancel {
    final link = _link;
    if (_historyReceipt != null ||
        link == null ||
        _cancelling ||
        _cancelNeedsRefresh ||
        _statusUnavailable) {
      return false;
    }
    return link.isPending &&
        !link.isCancelled &&
        !link.isExpired &&
        !link.isPaid &&
        !link.hasObservedOnchainPayment &&
        !link.isFailed;
  }

  Future<void> _confirmAndCancelPaymentLink() async {
    final link = _link;
    if (!_canAct || _cancelDialogOpen || link == null || !_linkCanCancel) {
      return;
    }
    final tr = context.tr;
    _cancelDialogOpen = true;
    final bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Consumer(builder: (ctx, dialogRef, _) {
          dialogRef.watch(sessionStorageScopeProvider);
          final allowed = _canAct;
          return AlertDialog(
            backgroundColor: _flowTokens(ctx).surfaceHigh,
            title: Text(
              tr.receivePaymentLinkCancelTitle,
              style: AppTypography.inter(
                color: _flowTokens(ctx).textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: allowed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Text(tr.receivePaymentLinkCancelMessage,
                            style: AppTypography.inter(
                              color: _flowTokens(ctx).textSecondary,
                              fontSize: 14,
                            )),
                        const SizedBox(height: 16),
                        Text(_requestedAmountLabel),
                        const SizedBox(height: 8),
                        SelectableText(link.id),
                      ])
                : Text(tr.securitySessionChangedMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(tr.receiveCancelBackAction),
              ),
              TextButton(
                onPressed: allowed ? () => Navigator.of(ctx).pop(true) : null,
                style: TextButton.styleFrom(
                  foregroundColor: _flowTokens(ctx).textPrimary,
                ),
                child: Text(tr.receivePaymentLinkConfirmCancel),
              ),
            ],
          );
        }),
      );
    } finally {
      _cancelDialogOpen = false;
    }
    if (confirmed != true || !_canAct) {
      return;
    }
    if (_link?.id != link.id || !_linkCanCancel) {
      SnackbarHelper.showInfo(tr.receiveCancelNoLongerAvailable);
      return;
    }

    setState(() {
      _cancelling = true;
      _linkRevision++;
    });
    try {
      final updated = await ref
          .read(transactionRepositoryProvider)
          .cancelPaymentRequest(link.id);
      if (!mounted || !_owns) return;
      if (updated.id != link.id || !updated.isCancelled) {
        setState(() {
          _cancelling = false;
          _cancelNeedsRefresh = true;
        });
        if (_canAct) SnackbarHelper.showInfo(tr.receiveCancelUnconfirmed);
        _startPaymentLinkPolling();
        return;
      }
      _statusTimer?.cancel();
      setState(() {
        _link = updated;
        if (_historyReceipt?.status != TransactionStatus.confirmed) {
          _applyPaymentLinkStage(updated);
        }
        _cancelling = false;
      });
      ref.invalidate(paymentLinksProvider);
      ref.invalidate(transactionHistoryProvider);
      if (_canAct) SnackbarHelper.showSuccess(tr.receivePaymentLinkCancelled);
    } catch (error) {
      if (!mounted || !_owns) return;
      setState(() {
        _cancelling = false;
        _cancelNeedsRefresh = true;
      });
      if (_canAct) {
        SnackbarHelper.showError(
          ErrorTranslator.translate(context.tr, error.toString()),
        );
      }
      _startPaymentLinkPolling();
    }
  }

  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionStorageScopeProvider, (_, next) {
      if (next?.trim() != _ownerScope) {
        _scopeLost = true;
        _statusTimer?.cancel();
        _expiryTicker?.cancel();
      }
    });
    ref.watch(sessionStorageScopeProvider);
    if (!_owns || !_foreground) {
      return Scaffold(
          backgroundColor: _receiveBackground,
          body: SafeArea(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        KeroseneIcon(KeroseneIcons.lock,
                            size: 28, color: _receiveText),
                        const SizedBox(height: 16),
                        Text(
                            !_owns
                                ? context.tr.securitySessionChangedMessage
                                : context.tr.receiveBackgroundHidden,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium
                                .copyWith(color: _receiveText)),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(MaterialLocalizations.of(context)
                                .closeButtonLabel)),
                      ])))));
    }
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
        ReceiveRequestStage.closed => _buildClosedScreen(context),
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
                  duration:
                      KeroseneMotion.duration(context, KeroseneMotion.medium),
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
                if (_statusUnavailable) ...[
                  const SizedBox(height: 12),
                  InlineNotice(message: context.tr.receiveStatusUnavailable),
                ],
                if (_cancelNeedsRefresh) ...[
                  const SizedBox(height: 12),
                  InlineNotice(message: context.tr.receiveCancelUnconfirmed),
                ],
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
              onTap: _presentationBusy || !_canAct ? null : _sharePaymentValue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClosedScreen(BuildContext context) {
    final link = _link;
    final transferStatus =
        (_observedTransfer?.status ?? _allocation?.transferStatus ?? '')
            .toUpperCase();
    final title = link?.isCancelled == true ||
            const ['CANCELLED', 'CANCELED'].contains(transferStatus)
        ? context.tr.receiveRequestCancelled
        : link?.isFailed == true || transferStatus == 'FAILED'
            ? context.tr.receiveRequestFailed
            : context.tr.receiveRequestExpired;
    final observedSats = link?.partialPaymentReceivedSats;
    final money = widget.money ?? const MovementMoney();
    return Column(children: [
      ReceiveContextHeader(
          title: title,
          icon: KeroseneIcons.arrowBack,
          onPressed: () => Navigator.of(context).maybePop()),
      Expanded(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeroseneIcon(KeroseneIcons.warning,
                        size: 48, color: _flowTokens(context).feedbackWarning),
                    const SizedBox(height: 20),
                    Text(title,
                        style: AppTypography.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: _receiveText),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(context.tr.receiveClosedBody,
                        style: AppTypography.bodyMedium
                            .copyWith(color: _receiveMuted),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    DetailRow(
                        label: ReceiveMoneyCopy.detailRequested(context),
                        value: _requestedAmountLabel,
                        secondaryValue: money.secondary(widget.amountBtc)),
                    if (observedSats != null && observedSats > 0) ...[
                      DetailRow(
                          label: context.tr.receiveObservedAmount,
                          value: money.primary(observedSats / 100000000.0),
                          secondaryValue:
                              money.secondary(observedSats / 100000000.0)),
                      const SizedBox(height: 12),
                      Text(context.tr.receivePartialBody,
                          style: AppTypography.bodySmall
                              .copyWith(color: _receiveMuted)),
                    ],
                    if (_statusUnavailable) ...[
                      const SizedBox(height: 12),
                      InlineNotice(message: context.tr.receiveStatusUnavailable)
                    ],
                  ]))),
      Padding(
          padding: const EdgeInsets.all(24),
          child: ReceiveActionButton(
              icon: KeroseneIcons.refresh,
              label: context.tr.receiveCheckStatus,
              onTap: () {
                if (_link != null) {
                  _refreshPaymentLink();
                } else {
                  _refreshObservedTransfer();
                }
              })),
    ]);
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
              icon: const KeroseneIcon(KeroseneIcons.back, size: 20),
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
              key: const ValueKey('receive-cancel-request'),
              tooltip: canCancel
                  ? context.tr.receivePaymentLinkCancelTitle
                  : MaterialLocalizations.of(context).closeButtonTooltip,
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
                  : KeroseneIcon(KeroseneIcons.close,
                      size: 18, color: _expiryColor),
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
        color: _flowTokens(context).surface,
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
            secondaryValue: widget.money?.secondary(widget.amountBtc) ?? '',
          ),
          const ReceiveDivider(),
          _buildAddressPill(context),
          if ((_link?.partialPaymentReceivedSats ?? 0) > 0) ...[
            const ReceiveDivider(),
            DetailRow(
                label: context.tr.receiveObservedAmount,
                value: (widget.money ?? const MovementMoney())
                    .primarySatoshis(_link!.partialPaymentReceivedSats!),
                secondaryValue: widget.money?.secondary(
                        _link!.partialPaymentReceivedSats! / 100000000.0) ??
                    ''),
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(context.tr.receivePartialBody,
                    style: AppTypography.bodySmall
                        .copyWith(color: _receiveMuted))),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressPill(BuildContext context) {
    final label = _isLightningReceive
        ? ReceiveMoneyCopy.detailInvoice(context)
        : ReceiveMoneyCopy.detailAddress(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.captionLarge.copyWith(
                    color: _receiveMuted,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('receive-address-pill-copy'),
                onPressed: _presentationBusy || !_canAct || !_canShareRequest
                    ? null
                    : _copyRawAddress,
                tooltip: context.tr.copy,
                icon: KeroseneIcon(KeroseneIcons.copy,
                    size: 18, color: _receiveMuted),
              ),
            ],
          ),
          SelectableText(
            _addressValue,
            textDirection: TextDirection.ltr,
            style: AppTypography.technicalMono(
              color: _receiveText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyRawAddress() async {
    if (!_canShareRequest || _stage == ReceiveRequestStage.identified) return;
    final payload = _isLightningReceive ? _paymentValue : _addressValue;
    await _copyPayload(
        payload,
        _isLightningReceive
            ? ReceiveMoneyCopy.invoiceCopied(context)
            : ReceiveMoneyCopy.addressCopied(context));
  }

  Future<void> _copyPayload(String payload, String successMessage) async {
    if (!_canAct || _presentationBusy || payload.trim().isEmpty) return;
    final failureMessage = context.tr.copyDataFailed;
    setState(() => _presentationBusy = true);
    try {
      await Clipboard.setData(ClipboardData(text: payload));
      if (!_canAct) return;
      SnackbarHelper.showSuccess(successMessage);
    } catch (_) {
      if (_canAct) SnackbarHelper.showError(failureMessage);
    } finally {
      if (mounted) setState(() => _presentationBusy = false);
    }
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
                if (_canShareRequest)
                  _buildQrBox(size: 180)
                else
                  InlineNotice(message: context.tr.receiveExpiredTracking),
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
                if (_statusUnavailable) ...[
                  const SizedBox(height: 12),
                  InlineNotice(message: context.tr.receiveStatusUnavailable),
                ],
                const SizedBox(height: 18),
                if (_canShareRequest)
                  Row(
                    children: [
                      Expanded(
                        child: ReceiveActionButton(
                          icon: KeroseneIcons.copy,
                          label: context.tr.copy,
                          onTap: _presentationBusy || !_canAct
                              ? null
                              : _copyPaymentValue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ReceiveActionButton(
                          icon: KeroseneIcons.share,
                          label: context.tr.share,
                          primary: true,
                          onTap: _presentationBusy || !_canAct
                              ? null
                              : _sharePaymentValue,
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
                if (_cancelNeedsRefresh || _link?.isCancelled == true)
                  MovementConfirmationRow(
                      label: context.tr.receiveReceiptRequestStatus,
                      value: _cancelNeedsRefresh
                          ? context.tr.receiveCancelUnconfirmed
                          : context.tr.receiveRequestCancelled),
                MovementConfirmationRow(
                  label: context.tr.sendReviewStatus,
                  value: _statusLabel,
                ),
                MovementConfirmationRow(
                  label: context.tr.sendReviewDestination,
                  value: _addressValue,
                  technical: true,
                ),
                MovementConfirmationRow(
                  label: ReceiveMoneyCopy.detailNetwork(context),
                  value: _networkLabel,
                ),
                MovementConfirmationRow(
                  label: ReceiveMoneyCopy.detailDate(context),
                  value: _receiptDateLabel,
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
                    backgroundColor: _flowTokens(context).ctaBackground,
                    foregroundColor: _flowTokens(context).ctaForeground,
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
                  onPressed:
                      _presentationBusy || !_canAct ? null : _sharePaymentValue,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _flowTokens(context).textPrimary,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const KeroseneIcon(KeroseneIcons.share, size: 17),
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
    final exact = widget.money?.secondary(_displayAmountBtc) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _amountLabel,
          textAlign: TextAlign.center,
          style: AppTypography.amountInput(
            isBtc: true,
            color: _receiveText,
          ).copyWith(fontSize: 26, height: 1.12, letterSpacing: 0),
        ),
        if (exact.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            exact,
            textAlign: TextAlign.center,
            style: AppTypography.number.copyWith(
              color: _receiveMuted,
              fontSize: 14,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}
