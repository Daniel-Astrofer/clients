import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/features/presentation/widgets/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/core/utils/bitcoin_network.dart';
import 'package:kerosene/core/utils/error_translator.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_key_vault.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_spend_coordinator.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/wallet_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/movement/data/payment_security_guards.dart';
import 'package:kerosene/features/movement/presentation/send/send_security_profile_resolver.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_amount_surface.dart';
import 'package:kerosene/features/security/domain/entities/account_security_profile.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'package:kerosene/features/security/presentation/widgets/transaction_auth_gate.dart';
import 'package:bitcoin_base/bitcoin_base.dart';

/// Send from a software cold wallet: PSBT on KFE, local seed sign, broadcast.
class ColdWalletSendScreen extends ConsumerStatefulWidget {
  final BitcoinAccount account;

  const ColdWalletSendScreen({super.key, required this.account});

  @override
  ConsumerState<ColdWalletSendScreen> createState() =>
      _ColdWalletSendScreenState();
}

class _ColdWalletSendScreenState extends ConsumerState<ColdWalletSendScreen> {
  final _destinationController = TextEditingController();
  final _feeController = TextEditingController(text: '2');

  String _amountDigits = '0';
  bool _busy = false;
  String? _statusLabel;
  bool _hasLocalSeed = false;
  bool _showAdvancedFee = false;

  String get _coldWalletId {
    final cold = widget.account.coldWalletId?.trim();
    if (cold != null && cold.isNotEmpty) return cold;
    return widget.account.id.trim();
  }

  int get _amountSats => int.tryParse(_amountDigits) ?? 0;

  @override
  void initState() {
    super.initState();
    _probeSeed();
  }

  Future<void> _probeSeed() async {
    final has = await ColdWalletKeyVault.instance.hasSeed(_coldWalletId);
    if (mounted) {
      setState(() => _hasLocalSeed = has);
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<AccountSecurityProfile> _loadSecurityProfile() async {
    try {
      return await ref.read(accountSecurityProfileProvider.future);
    } catch (_) {
      return fallbackSendSecurityProfile('STANDARD');
    }
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_amountDigits.length <= 1) {
          _amountDigits = '0';
        } else {
          _amountDigits = _amountDigits.substring(0, _amountDigits.length - 1);
        }
        return;
      }
      if (key == '00') {
        if (_amountDigits == '0') return;
        if (_amountDigits.length >= 12) return;
        _amountDigits = '$_amountDigits$key';
        return;
      }
      if (!RegExp(r'^\d$').hasMatch(key)) return;
      if (_amountDigits == '0') {
        _amountDigits = key;
      } else if (_amountDigits.length < 14) {
        _amountDigits = '$_amountDigits$key';
      }
    });
  }

  BasedUtxoNetwork _signingNetwork(String destination) {
    final kind = inferBitcoinNetworkFromAddress(destination);
    return switch (kind) {
      BitcoinNetworkKind.mainnet => BitcoinNetwork.mainnet,
      BitcoinNetworkKind.regtest => BitcoinNetwork.testnet,
      _ => BitcoinNetwork.testnet,
    };
  }

  bool _looksLikeOnchainAddress(String value) {
    final n = value.trim().toLowerCase();
    if (n.isEmpty) return false;
    return n.startsWith('bc1') ||
        n.startsWith('tb1') ||
        n.startsWith('bcrt1') ||
        RegExp(r'^(1|3|m|n|2)[a-zA-HJ-NP-Z0-9]{20,90}$').hasMatch(n);
  }

  Future<String?> _resolveDestinationAddress() async {
    final raw = _destinationController.text.trim();
    if (raw.isEmpty) {
      AppNotice.showWarning(
        context,
        title: context.tr.sendReviewDestination,
        message: context.tr.coldSendDestinationHint,
      );
      return null;
    }
    if (_looksLikeOnchainAddress(raw)) {
      return raw;
    }

    // Match own spendable wallets by label/id and use their receive address.
    final walletState = ref.read(walletProvider);
    final wallets =
        walletState is WalletLoaded ? walletState.wallets : const <Wallet>[];
    final needle = raw.replaceFirst(RegExp(r'^@'), '').toLowerCase();
    for (final wallet in wallets) {
      if (wallet.isColdWallet || wallet.isSelfCustody) continue;
      final id = wallet.id.trim().toLowerCase();
      final name = wallet.name.trim().toLowerCase();
      if (id == needle || name == needle) {
        final address = wallet.address.trim();
        if (address.isEmpty) {
          AppNotice.showError(
            context,
            title: context.tr.coldSendNoAddress,
            message:
                'A carteira ${wallet.name} ainda não tem endereço on-chain. Gere um na aba receber e tente de novo.',
          );
          return null;
        }
        return address;
      }
    }

    AppNotice.showWarning(
      context,
      title: context.tr.coldSendOnchainDestination,
      message:
          'Para pagar com a cold, use um endereço Bitcoin (tb1…/bc1…) ou o endereço de uma carteira Kerosene sua listada abaixo.',
    );
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_hasLocalSeed) {
      AppNotice.showError(
        context,
        title: context.tr.coldSendMissingSeed,
        message:
            'Esta cold não tem seed neste aparelho. Restaure o backup BIP39 neste aparelho para assinar.',
      );
      return;
    }

    if (_amountSats < 546) {
      AppNotice.showWarning(
        context,
        title: 'Valor',
        message: 'Informe um valor de pelo menos 546 sats.',
      );
      return;
    }

    final destination = await _resolveDestinationAddress();
    if (destination == null || !mounted) return;

    // Fail-closed: network must match app network.
    final networkError =
        networkMismatchMessage(destination, context: context);
    if (networkError != null) {
      AppNotice.showError(
        context,
        title: context.tr.coldSendNetworkMismatch,
        message: networkError,
      );
      return;
    }

    // First-time destination confirmation (address poisoning guard).
    final confirmed = await confirmFirstTimeOnchainAddress(
      context: context,
      address: destination,
    );
    if (!confirmed || !mounted) return;

    // Same auth ritual as custodial send — no free-text TOTP field.
    final profile = await _loadSecurityProfile();
    if (!mounted) return;
    final auth = await TransactionAuthGate.show(
      context,
      profile: profile,
      forceTotp: true,
      // Never skip device/server factors just because biometrics are unavailable.
      allowDeviceAuthUnavailable: false,
    );
    if (!mounted) return;
    // Intentional cancel (PIN/back/biometrics) — stay on form, no error chrome.
    if (auth.isCancelled) {
      return;
    }
    if (auth.isUnavailable) {
      AppNotice.showWarning(
        context,
        title: context.tr.coldSendAuth,
        message: context.tr.sendMoneyAuthFailed,
      );
      return;
    }
    if (!auth.isAuthenticated) {
      AppNotice.showWarning(
        context,
        title: context.tr.coldSendAuth,
        message: context.tr.sendMoneyAuthFailed,
      );
      return;
    }

    final totp = auth.totpCode?.trim() ?? '';
    if (totp.length < 6) {
      AppNotice.showError(
        context,
        title: context.tr.coldSendAuthIncompleteTitle,
        message:
            'É necessário o código do autenticador (TOTP) para montar a PSBT da cold.',
      );
      return;
    }

    final fee = int.tryParse(_feeController.text.trim());
    setState(() {
      _busy = true;
      _statusLabel = 'Montando transação…';
    });

    try {
      final coordinator = ColdWalletSpendCoordinator(
        accountsService: ref.read(bitcoinAccountsServiceProvider),
      );
      if (mounted) {
        setState(() => _statusLabel = 'Assinando no aparelho…');
      }
      final result = await coordinator.spend(
        coldWalletId: _coldWalletId,
        destinationAddress: destination,
        amountSats: _amountSats,
        totpCode: totp,
        feeRateSatsPerVbyte: fee != null && fee > 0 ? fee : null,
        network: _signingNetwork(destination),
        broadcast: true,
      );

      ref.invalidate(bitcoinColdWalletUtxosProvider(_coldWalletId));
      ref.invalidate(bitcoinColdWalletPsbtsProvider(_coldWalletId));

      if (!mounted) return;
      final txid = result.txid?.trim();
      AppNotice.showSuccess(
        context,
        title: context.tr.coldSendSuccess,
        message: txid != null && txid.isNotEmpty
            ? 'Enviada: $txid'
            : 'Assinada e enviada ao Kerosene (status ${result.workflow.status}).',
      );
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      AppNotice.showError(
        context,
        title: context.tr.coldSendFailed,
        message: ErrorTranslator.translate(context.tr, error.toString()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _statusLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.account.label.trim().isEmpty
        ? context.tr.bitcoinAccountsColdWalletBadge
        : widget.account.label.trim();
    final walletState = ref.watch(walletProvider);
    final wallets =
        walletState is WalletLoaded ? walletState.wallets : const <Wallet>[];
    final keroseneTargets = wallets
        .where((w) =>
            !w.isColdWallet &&
            !w.isSelfCustody &&
            w.address.trim().isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: KeroseneBrandTokens.background,
      appBar: AppBar(
        backgroundColor: KeroseneBrandTokens.background,
        foregroundColor: KeroseneBrandTokens.textPrimary,
        title: Text(
          context.tr.coldSendTitle,
          style: AppTypography.inter(
            color: KeroseneBrandTokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              label,
              style: AppTypography.inter(
                color: KeroseneBrandTokens.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasLocalSeed
                  ? 'Você assina no aparelho. A seed nunca sai deste dispositivo; o Kerosene só observa a blockchain.'
                  : 'Sem backup neste aparelho — restaure a seed BIP39 para assinar envios.',
              style: AppTypography.inter(
                color: _hasLocalSeed
                    ? KeroseneBrandTokens.textSecondary
                    : KeroseneBrandTokens.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr.coldSendOnchainDestination,
              style: AppTypography.inter(
                color: KeroseneBrandTokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              style: AppTypography.inter(
                color: KeroseneBrandTokens.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: context.tr.coldSendAddressHint,
                hintStyle: AppTypography.inter(
                  color: KeroseneBrandTokens.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: KeroseneBrandTokens.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: KeroseneBrandTokens.border),
                ),
              ),
            ),
            if (keroseneTargets.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                context.tr.coldSendPayKeroseneWallet,
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final wallet in keroseneTargets)
                    ActionChip(
                      avatar: Icon(
                        KeroseneIcons.wallet,
                        size: 16,
                        color: KeroseneBrandTokens.textPrimary,
                      ),
                      label: Text(
                        wallet.name.trim().isEmpty
                            ? shortId(wallet.id)
                            : wallet.name,
                        style: AppTypography.inter(
                          color: KeroseneBrandTokens.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _destinationController.text =
                                    wallet.address.trim();
                              });
                            },
                      backgroundColor: KeroseneBrandTokens.surfaceHigh,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            TransactionAmountSurface(
              title: 'Valor',
              direction: TransactionAmountDirection.send,
              amountLabel: _formatSats(_amountSats),
              unitLabel: 'sats',
              amountMuted: _amountSats <= 0,
              keypadMode: TransactionKeypadMode.integer,
              showKeypad: true,
              onKeyTap: _busy ? null : _onKey,
              ctaEnabled: false,
              details: [
                TransactionDetailRowData(
                  label: 'Taxa (sats/vB)',
                  value: _feeController.text.trim().isEmpty
                      ? 'auto'
                      : _feeController.text.trim(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _showAdvancedFee = !_showAdvancedFee),
                child: Text(
                  _showAdvancedFee
                      ? 'Ocultar taxa avançada'
                      : 'Taxa avançada (opcional)',
                  style: AppTypography.inter(
                    color: KeroseneBrandTokens.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_showAdvancedFee) ...[
              TextField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'Taxa recomendada (sats/vB)',
                  helperText: 'Deixe em branco ou use o valor sugerido.',
                  labelStyle: AppTypography.inter(
                    color: KeroseneBrandTokens.textMuted,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: KeroseneBrandTokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            if (_statusLabel != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusLabel!,
                style: AppTypography.inter(
                  color: KeroseneBrandTokens.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _busy || !_hasLocalSeed || _amountSats < 546
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: KeroseneBrandTokens.textPrimary,
                  foregroundColor: KeroseneBrandTokens.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.tr.coldSendSignBroadcast,
                        style: AppTypography.inter(
                          color: KeroseneBrandTokens.background,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSats(int sats) {
    final raw = sats.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final fromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  String shortId(String id) {
    final t = id.trim();
    if (t.length <= 10) return t;
    return '${t.substring(0, 6)}…${t.substring(t.length - 4)}';
  }
}
