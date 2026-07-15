import 'package:bitcoin_base/bitcoin_base.dart';

import 'package:kerosene/features/financial_accounts/domain/services/bitcoin_accounts_service.dart';
import 'package:kerosene/features/financial_accounts/domain/services/cold_wallet_psbt_signer.dart';

/// End-to-end cold spend: create PSBT (KFE) → sign local seed → submit + broadcast.
class ColdWalletSpendCoordinator {
  ColdWalletSpendCoordinator({
    required BitcoinAccountsService accountsService,
    ColdWalletPsbtSigner? signer,
  })  : _accounts = accountsService,
        _signer = signer ?? ColdWalletPsbtSigner.instance;

  final BitcoinAccountsService _accounts;
  final ColdWalletPsbtSigner _signer;

  Future<ColdWalletSpendResult> spend({
    required String coldWalletId,
    required String destinationAddress,
    required int amountSats,
    required String totpCode,
    int? feeRateSatsPerVbyte,
    List<String> selectedUtxoIds = const [],
    BasedUtxoNetwork network = BitcoinNetwork.testnet,
    bool broadcast = true,
  }) async {
    final dest = destinationAddress.trim();
    if (dest.isEmpty) {
      throw const ColdWalletSpendException(
        'ERR_COLD_SPEND_DESTINATION',
        'Informe o endereço on-chain de destino.',
      );
    }
    if (amountSats < 546) {
      throw const ColdWalletSpendException(
        'ERR_COLD_SPEND_DUST',
        'Valor mínimo on-chain é 546 sats.',
      );
    }
    final totp = totpCode.trim();
    if (totp.isEmpty) {
      throw const ColdWalletSpendException(
        'ERR_COLD_SPEND_TOTP',
        'Informe o código TOTP para montar a PSBT.',
      );
    }

    final created = await _accounts.createColdWalletPsbt(
      coldWalletId: coldWalletId,
      destinationAddress: dest,
      amountSats: amountSats,
      feeRate: feeRateSatsPerVbyte,
      selectedUtxoIds: selectedUtxoIds,
      totpCode: totp,
    );

    final unsigned = created.unsignedPsbt.trim();
    if (unsigned.isEmpty) {
      throw const ColdWalletSpendException(
        'ERR_COLD_SPEND_EMPTY_PSBT',
        'O servidor retornou uma PSBT vazia.',
      );
    }

    final signed = await _signer.signPsbt(
      walletId: coldWalletId,
      unsignedPsbtBase64: unsigned,
      network: network,
    );

    final workflow = await _accounts.submitSignedPsbt(
      workflowId: created.id,
      signedPsbt: signed,
      broadcast: broadcast,
    );

    return ColdWalletSpendResult(
      workflow: workflow,
      signedPsbt: signed,
      broadcasted: broadcast,
    );
  }
}

class ColdWalletSpendResult {
  final PsbtWorkflowView workflow;
  final String signedPsbt;
  final bool broadcasted;

  const ColdWalletSpendResult({
    required this.workflow,
    required this.signedPsbt,
    required this.broadcasted,
  });

  String? get txid => workflow.broadcastTxid;
}

class ColdWalletSpendException implements Exception {
  final String code;
  final String message;

  const ColdWalletSpendException(this.code, this.message);

  @override
  String toString() => 'ColdWalletSpendException($code): $message';
}
