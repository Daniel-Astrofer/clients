import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kerosene/core/motion/app_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/design_system/icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/providers/money_format_provider.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/responsive/kerosene_responsive.dart';
import 'package:kerosene/core/theme/app_typography.dart';
import 'package:kerosene/core/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/core/utils/money_display.dart';
import 'package:kerosene/core/utils/qr_payment_parser.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/movement/copy/receive_money_copy.dart';
import 'package:kerosene/features/movement/domain/entities/external_transfer.dart';
import 'package:kerosene/features/movement/domain/entities/onchain_address_allocation.dart';
import 'package:kerosene/features/movement/domain/entities/payment_link.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/widgets/movement_confirmation_surface.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/screens/receive_method.dart';
import 'receive_request_flow_components.dart';

enum ReceiveRequestStage { qr, confirmations, identified }

const _receiveBackground = KeroseneBrandTokens.background;
const _receiveText = KeroseneBrandTokens.textPrimary;
const _receiveMuted = KeroseneBrandTokens.textMuted;

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
  });

  @override
  ConsumerState<ReceiveRequestFlowScreen> createState() =>
      _ReceiveRequestFlowScreenState();
}

class _ReceiveRequestFlowScreenState
    extends ConsumerState<ReceiveRequestFlowScreen>
    with SingleTickerProviderStateMixin {
  Timer? _statusTimer;
  late final AnimationController _scanController;
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

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: KeroseneMotion.ceremonial,
    )..repeat();
    _stage = widget.initialStage ?? ReceiveRequestStage.qr;
    _identifiedAt = widget.identifiedAt ?? DateTime.now();
    _link = widget.initialPaymentLink;
    _address = widget.initialAddress ?? _link?.depositAddress;
    _paymentUri = widget.initialPaymentUri ?? _paymentUriFor(_link);
    _txid = widget.initialTxid ?? _link?.txid;

    if (widget.enableStatusPolling) {
      scheduleMicrotask(_prepareRequest);
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _prepareRequest() async {
    final link = _link;
    if (widget.onChainWallet && link == null) {
      await _issueOnchainAddress();
      return;
    }

    if (link != null) {
      _applyPaymentLinkStage(link);
      if (_stage == ReceiveRequestStage.identified) {
        return;
      }
      _startPaymentLinkPolling();
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
      final translated =
          ErrorTranslator.translate(context.tr, error.toString());
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
    _statusTimer = Timer.periodic(
      KeroseneMotion.notificationLongHold,
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
    _statusTimer = Timer.periodic(
      KeroseneMotion.notificationLongHold,
      (_) => _refreshPaymentLink(),
    );
  }

  Future<void> _refreshPaymentLink() async {
    final linkId = _link?.id.trim() ?? '';
    if (linkId.isEmpty) return;

    try {
      final PaymentLink latest;
      latest = await ref.read(transactionRepositoryProvider).getPaymentLink(
            linkId,
          );

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
      _paymentUri = bolt11;
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
    // Lightning settles in one step (invoice paid) — no multi-conf wait.
    final complete = link.isCompleted ||
        (isLightning && link.isPaid) ||
        (!onChain && !isLightning && link.isPaid) ||
        (onChain &&
            link.isPaid &&
            link.confirmations >= _requiredConfirmations);
    if (complete) {
      _stage = ReceiveRequestStage.identified;
      _identifiedAt = link.completedAt ?? link.paidAt ?? DateTime.now();
      return;
    }
    if (link.isPaid ||
        link.isVerifyingOnboarding ||
        link.confirmations > 0 ||
        link.hasObservedOnchainPayment) {
      _stage = ReceiveRequestStage.confirmations;
      return;
    }
    _stage = ReceiveRequestStage.qr;
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
    // Lightning: QR must encode the BOLT11 invoice, not a truncated address.
    final bolt11 = link.paymentRequest?.trim();
    if (link.isLightningPaymentRequest &&
        bolt11 != null &&
        bolt11.isNotEmpty) {
      return bolt11;
    }
    final shareable = link.shareablePaymentPayload;
    if (shareable.toLowerCase().startsWith('ln')) {
      return shareable;
    }
    final address = link.depositAddress.trim();
    final hasChainAddress =
        address.isNotEmpty && looksLikeBitcoinAddress(address);

    // Prefer BIP-21 whenever we have a real chain address (testnet tb1 / mainnet).
    if (hasChainAddress) {
      return QrPaymentParser.encode(
        address: address,
        amountBtc: link.amountBtc > 0 ? link.amountBtc : widget.amountBtc,
        label: widget.wallet.name,
        message: link.description,
      );
    }

    final explicitUri = link.paymentUri?.trim();
    if (explicitUri != null &&
        explicitUri.isNotEmpty &&
        !explicitUri.toLowerCase().startsWith('bitcoin:')) {
      // kerosene://… internal payment URI or raw bolt11
      return explicitUri;
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
    final link = _link;
    if (link != null) {
      final shareable = link.shareablePaymentPayload.trim();
      if (shareable.isNotEmpty) return shareable;
    }
    final current = _paymentUri?.trim() ?? '';
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
            'testnet' || 'testnet4' || 'testnet3' => 'On-chain · Bitcoin Testnet',
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
    final amount = MoneyDisplay.formatCompact(
      amount: widget.amountBtc,
      currency: Currency.btc,
      withSymbol: false,
      maxDecimalPlaces: 8,
    );
    return '$amount BTC';
  }

  String get _requestedAmountLabel {
    final amount = MoneyDisplay.format(
      amount: widget.amountBtc,
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
    return '≈ ${money.formatAmountFromBtc(
      btcAmount: widget.amountBtc,
      currency: fiat,
      btcUsd: ref.watch(latestBtcPriceProvider),
      btcEur: ref.watch(btcEurPriceProvider),
      btcBrl: ref.watch(btcBrlPriceProvider),
    )}';
  }

  Future<void> _copyPaymentValue() async {
    final successMessage = context.tr.receiveQrCopied;
    await Clipboard.setData(ClipboardData(text: _paymentValue));
    await HapticFeedback.selectionClick();
    SnackbarHelper.showSuccess(successMessage);
  }

  Future<void> _sharePaymentValue() async {
    // Platform share sheet is not wired globally; clipboard + clear toast for now.
    final successMessage = ReceiveMoneyCopy.shareReceiptHint(context);
    await Clipboard.setData(ClipboardData(text: _paymentValue));
    if (!mounted) return;
    await HapticFeedback.selectionClick();
    SnackbarHelper.showSuccess(successMessage);
  }

  void _goHome() {
    HapticFeedback.selectionClick();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final child = switch (_stage) {
      ReceiveRequestStage.qr => _buildQrScreen(context),
      ReceiveRequestStage.confirmations => _buildConfirmationsScreen(context),
      ReceiveRequestStage.identified => _buildIdentifiedScreen(context),
    };

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
                  child: KeyedSubtree(key: ValueKey(_stage), child: child),
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
    final receiveTitle = _receiveFlowTitle;
    final pendingTitle = ReceiveMoneyCopy.qrPendingTitle(context);
    return Column(
      children: [
        ReceiveContextHeader(
          title: pendingTitle,
          icon: KeroseneIcons.close,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  receiveTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.newsreader(
                    color: _receiveText,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 22),
                _buildQrBox(size: 180, showScanLine: true),
                const SizedBox(height: 20),
                _buildQrAmount(),
                const SizedBox(height: 16),
                _buildReceiveDetails(context),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  InlineNotice(message: _errorMessage!),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Row(
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
                  onTap: _sharePaymentValue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiveDetails(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: KeroseneBrandTokens.surface,
        border: Border.all(color: KeroseneBrandTokens.border),
        borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.inter(
              color: _receiveMuted,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('receive-address-pill-copy'),
              behavior: HitTestBehavior.opaque,
              onTap: _copyRawAddress,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(KeroseneIcons.copy, size: 15, color: _receiveMuted),
                ],
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  receiveTitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.newsreader(
                    color: _receiveText,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 22),
                _buildQrBox(size: 180),
                const SizedBox(height: 16),
                _buildQrAmount(),
                const SizedBox(height: 16),
                _buildReceiveDetails(context),
                const SizedBox(height: 16),
                ReceiveNetworkStatusRow(
                  onChainWallet: _isOnChainReceive,
                  lightning: _isLightningReceive,
                  identified: _stage == ReceiveRequestStage.identified,
                  currentConfirmations:
                      _currentConfirmations.clamp(0, _requiredConfirmations).toInt(),
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
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: MovementConfirmationSurface(
              leading: ReceiveSuccessGraphic(animation: _scanController),
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _goHome,
                  style: FilledButton.styleFrom(
                    backgroundColor: KeroseneBrandTokens.textPrimary,
                    foregroundColor: KeroseneBrandTokens.background,
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
                    foregroundColor: KeroseneBrandTokens.textPrimary,
                    side: const BorderSide(color: KeroseneBrandTokens.border),
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

  Widget _buildQrBox({required double size, bool showScanLine = false}) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          QrImageView(
            data: _paymentValue,
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
          ),
          if (showScanLine)
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                final offset = -size * 0.25 + _scanController.value * size;
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      height: size * 0.16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildQrAmount() {
    return Text(
      _amountLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: AppTypography.inter(
        color: _receiveText,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.12,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
