import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kerosene/core/errors/exceptions.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_public_material.dart';
import 'package:kerosene/app/security/payment_security_guards.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/design_system/foundation/theme/app_typography.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_network.dart';
import 'package:kerosene/features/financial_accounts/domain/services/register_cold_wallet_use_case.dart';
import 'package:kerosene/features/financial_accounts/domain/services/watch_only_import.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'cold_wallet_success_screen.dart';

/// Registers validated public account material without requesting or storing a seed.
class WatchOnlyImportScreen extends ConsumerStatefulWidget {
  const WatchOnlyImportScreen({super.key, this.initialLabel = ''});
  final String initialLabel;
  @override
  ConsumerState<WatchOnlyImportScreen> createState() =>
      _WatchOnlyImportScreenState();
}

class _WatchOnlyImportScreenState extends ConsumerState<WatchOnlyImportScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _key = TextEditingController();
  final _fingerprint = TextEditingController();
  final _path = TextEditingController(text: appColdWalletDerivationPath);
  WatchOnlyImportError? _error;
  bool _busy = false;
  bool _unknown = false;
  bool _capacityBlocked = false;

  @override
  void initState() {
    super.initState();
    _label.text = widget.initialLabel;
  }

  @override
  void dispose() {
    _label.dispose();
    _key.dispose();
    _fingerprint.dispose();
    _path.dispose();
    super.dispose();
  }

  String? get _validationMessage => switch (_error) {
        WatchOnlyImportError.key => context.tr.walletPublicInvalidKey,
        WatchOnlyImportError.privateKey => context.tr.walletPublicPrivateKey,
        WatchOnlyImportError.network => context.tr.walletPublicWrongNetwork,
        WatchOnlyImportError.fingerprint =>
          context.tr.walletPublicInvalidFingerprint,
        WatchOnlyImportError.path => context.tr.walletPublicInvalidPath,
        WatchOnlyImportError.account => context.tr.walletPublicAccountMismatch,
        null => null,
      };

  Future<void> _submit() async {
    if (_busy || _unknown || !_form.currentState!.validate()) return;
    final material = _parse();
    if (material == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final result = await RegisterColdWalletUseCase(
              importColdWallet:
                  ref.read(bitcoinAccountsControllerProvider).importColdWallet)
          .registerPublicOnly(label: _label.text, material: material);
      if (!mounted) return;
      final outcome = await Navigator.of(context).push<ColdWalletFlowOutcome>(
          MaterialPageRoute(
              builder: (_) => ColdWalletSuccessScreen(
                  result: result, walletLabel: _label.text.trim())));
      if (mounted && outcome != null) Navigator.of(context).pop(outcome);
    } catch (error) {
      // A lost POST response can follow a successful registration. Do not
      // automatically retransmit or label it as a definitive creation failure.
      if (mounted) {
        setState(() {
          _capacityBlocked = error is ValidationException &&
              error.errorCode == 'ERR_WALLET_CUSTODY_ALREADY_EXISTS';
          _unknown = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Validate before constructing the registration request; no key text is logged.
  ColdWalletPublicMaterial? _parse() {
    try {
      final material = parseWatchOnlyImport(
          extendedPublicKey: _key.text,
          fingerprint: _fingerprint.text,
          derivationPath: _path.text,
          network: expectedBitcoinNetwork);
      setState(() => _error = null);
      return material;
    } on WatchOnlyImportError catch (error) {
      if (error == WatchOnlyImportError.privateKey) _key.clear();
      setState(() => _error = error);
      return null;
    }
  }

  Widget _field(String id, TextEditingController controller, String label,
          {String? hint, int? maxLength, int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ExcludeSemantics(
              child: Text(label,
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(height: 8),
          Semantics(
              label: label,
              child: TextFormField(
                key: ValueKey(id),
                controller: controller,
                enabled: !_busy && !_unknown,
                maxLength: maxLength,
                maxLines: maxLines,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                decoration: InputDecoration(
                    helperText: hint,
                    helperMaxLines: 4,
                    border: const OutlineInputBorder()),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.tr.walletPublicRequired
                    : null,
              )),
        ]),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
              toolbarHeight: 64,
              title: Text(context.tr.walletPublicImportTitle,
                  maxLines: 2,
                  style: AppTypography.inter(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              leading: BackButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).maybePop())),
          body: SafeArea(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.tr.walletPublicImportBody,
                        style: AppTypography.bodyMedium),
                    const SizedBox(height: 12),
                    Text(
                        context.tr.walletSetupNetwork(
                            coldWalletNetworkLabel(expectedBitcoinNetwork)),
                        style: AppTypography.bodySmall),
                    const SizedBox(height: 24),
                    _field('public-wallet-label', _label,
                        context.tr.walletPublicName,
                        maxLength: 80),
                    _field(
                        'public-wallet-key', _key, context.tr.walletPublicKey,
                        hint: context.tr.walletPublicKeyHint,
                        maxLength: 128,
                        maxLines: 3),
                    _field('public-wallet-fingerprint', _fingerprint,
                        context.tr.walletPublicFingerprint,
                        hint: context.tr.walletPublicOriginHint, maxLength: 8),
                    _field('public-wallet-path', _path,
                        context.tr.walletPublicPath,
                        hint: context.tr.walletPublicPathHint, maxLength: 64),
                    if (_validationMessage != null) ...[
                      Text(_validationMessage!,
                          style: AppTypography.bodyMedium.copyWith(
                              color: Theme.of(context).colorScheme.error)),
                      const SizedBox(height: 16),
                    ],
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(context.tr.walletSetupRegistering),
                      const SizedBox(height: 16),
                    ],
                    if (_unknown) ...[
                      Text(
                          _capacityBlocked
                              ? context.tr.coldCreateMaxTwo
                              : context.tr.walletPublicResultUnknown,
                          style: AppTypography.bodyMedium),
                      const SizedBox(height: 16),
                      OutlinedButton(
                          onPressed: () {
                            unawaited(ref
                                .read(bitcoinAccountsControllerProvider)
                                .refresh());
                            context.go('/accounts');
                          },
                          child: Text(context.tr.walletPublicCheckWallets)),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                        onPressed: _busy || _unknown ? null : _submit,
                        child: Text(context.tr.walletPublicRegister)),
                  ],
                )),
          )),
        ),
      );
}
