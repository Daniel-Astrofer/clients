import 'package:flutter/widgets.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/receive/receive_method.dart';

/// Receive-flow copy (en/es/pt), aligned with [SendMoneyCopy] style.
class ReceiveMoneyCopy {
  const ReceiveMoneyCopy._();

  static String hubTitle(BuildContext context) => switch (_language(context)) {
        'en' => 'How do you want to receive?',
        'es' => '¿Cómo deseas recibir?',
        _ => 'Como deseja receber?',
      };

  static String hubSubtitle(
    BuildContext context, {
    required bool isInternal,
    required bool isCold,
    required bool showNfc,
  }) {
    if (isCold) {
      return switch (_language(context)) {
        'en' => 'Choose QR or payment link to receive into this cold wallet.',
        'es' => 'Elige QR o link de pago para recibir en esta cold wallet.',
        _ =>
          'Escolha QR Code ou link de pagamento para receber nesta carteira fria.',
      };
    }
    if (!isInternal) {
      return switch (_language(context)) {
        'en' => 'Choose QR or payment link to receive on-chain.',
        'es' => 'Elige QR o link de pago para recibir on-chain.',
        _ => 'Escolha QR Code ou link de pagamento para receber on-chain.',
      };
    }
    if (showNfc) {
      return switch (_language(context)) {
        'en' =>
          'Choose Lightning, NFC, P2P, link, QR, or gateway to receive on Kerosene.',
        'es' =>
          'Elige Lightning, NFC, P2P, link, QR o gateway para recibir en Kerosene.',
        _ =>
          'Escolha Lightning, NFC, P2P, link, QR Code ou gateway para receber na plataforma.',
      };
    }
    return switch (_language(context)) {
      'en' =>
        'Choose Lightning, P2P, link, QR, or gateway to receive on Kerosene.',
      'es' =>
        'Elige Lightning, P2P, link, QR o gateway para recibir en Kerosene.',
      _ =>
        'Escolha Lightning, P2P, link, QR Code ou gateway para receber na plataforma.',
    };
  }

  static String hubWalletChip(BuildContext context, String walletName) {
    final clean = walletName.trim();
    if (clean.isEmpty) return '';
    return switch (_language(context)) {
      'en' => 'Into $clean',
      'es' => 'En $clean',
      _ => 'Em $clean',
    };
  }

  static String pickWalletTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Where should it land?',
        'es' => '¿Dónde quieres recibirlo?',
        _ => 'Onde deseja receber?',
      };

  static String pickWalletSubtitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Choose the wallet that will hold this receive.',
        'es' => 'Elige la billetera que recibirá este valor.',
        _ => 'Escolha a carteira que vai receber este valor.',
      };

  static String walletCustodyLabel(BuildContext context, Wallet wallet) {
    if (wallet.isColdWallet) {
      return switch (_language(context)) {
        'en' => 'Cold Wallet',
        'es' => 'Cold Wallet',
        _ => 'Cold Wallet',
      };
    }
    if (wallet.isCustodialOnchain) {
      return switch (_language(context)) {
        'en' => 'Custodial Onchain',
        'es' => 'Custodial Onchain',
        _ => 'Custodial Onchain',
      };
    }
    return switch (_language(context)) {
      'en' => 'Internal Wallet',
      'es' => 'Carteira Interna',
      _ => 'Carteira Interna',
    };
  }

  static String pointCameraHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Point your phone camera',
        'es' => 'Apunta la cámara del celular',
        _ => 'Aponte a câmera do celular',
      };

  static String receiveAmountTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'How much do you want to receive?',
        'es' => '¿Cuánto quieres recibir?',
        _ => 'Quanto deseja receber?',
      };

  /// Top-bar fallback when auth username is unavailable.
  static String receiveDestinationFallback(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Receive',
        'es' => 'Recibir',
        _ => 'Receber',
      };

  static String networkPickTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Choose the network',
        'es' => 'Elige la red',
        _ => 'Escolha a rede',
      };

  static String networkPickSubtitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Pick the rail with the best cost and settlement time.',
        'es' => 'Elige la red con mejor costo y tiempo de liquidación.',
        _ => 'Escolha a rede com melhor custo e tempo de liquidação.',
      };

  static String networkBestValue(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Best value',
        'es' => 'Mejor costo',
        _ => 'Melhor custo',
      };

  static String p2pTitle(BuildContext context) => switch (_language(context)) {
        'en' => 'P2P',
        'es' => 'P2P',
        _ => 'P2P',
      };

  static String amountTitle(
    BuildContext context,
    ReceiveAmountMethod method,
  ) =>
      switch (method) {
        ReceiveAmountMethod.qrCode => switch (_language(context)) {
            'en' => 'Receive via QR',
            'es' => 'Recibir por QR',
            _ => 'Receber via QR',
          },
        ReceiveAmountMethod.paymentLink => switch (_language(context)) {
            'en' => 'Payment link',
            'es' => 'Link de pago',
            _ => 'Link de pagamento',
          },
        ReceiveAmountMethod.nfc => switch (_language(context)) {
            'en' => 'Receive via NFC',
            'es' => 'Recibir por NFC',
            _ => 'Receber via NFC',
          },
        ReceiveAmountMethod.lightning => switch (_language(context)) {
            'en' => 'Receive Lightning',
            'es' => 'Recibir Lightning',
            _ => 'Receber Lightning',
          },
        ReceiveAmountMethod.p2p => switch (_language(context)) {
            'en' => 'Receive P2P',
            'es' => 'Recibir P2P',
            _ => 'Receber P2P',
          },
      };

  static String amountIntoWallet(BuildContext context, String walletName) {
    final clean = walletName.trim();
    if (clean.isEmpty) return '';
    return switch (_language(context)) {
      'en' => 'Into $clean',
      'es' => 'En $clean',
      _ => 'Em $clean',
    };
  }

  static String railLabel(
    BuildContext context,
    ReceiveAmountMethod method, {
    required bool onChainWallet,
  }) {
    return switch (method) {
      ReceiveAmountMethod.p2p => 'Kerosene',
      ReceiveAmountMethod.lightning => 'Lightning',
      ReceiveAmountMethod.nfc => onChainWallet ? 'On-chain · NFC' : 'NFC',
      ReceiveAmountMethod.qrCode => 'On-chain · QR',
      ReceiveAmountMethod.paymentLink => switch (_language(context)) {
          'en' => 'Payment link',
          'es' => 'Link de pago',
          _ => 'Link de pagamento',
        },
    };
  }

  static String lightningTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Lightning invoice',
        'es' => 'Factura Lightning',
        _ => 'Fatura Lightning',
      };

  static String lightningSubtitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Create a BOLT11 invoice to receive instantly',
        'es' => 'Crea una factura BOLT11 para recibir al instante',
        _ => 'Crie uma fatura BOLT11 para receber na hora',
      };

  static String paymentLinkDescription(
    BuildContext context,
    String walletName,
  ) =>
      switch (_language(context)) {
        'en' => 'Receive · $walletName',
        'es' => 'Recibir · $walletName',
        _ => 'Recebimento · $walletName',
      };

  static String qrPendingTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Pending',
        'es' => 'Pendiente',
        _ => 'Pendente',
      };

  static String receiveBitcoinTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Receive Bitcoin',
        'es' => 'Recibir Bitcoin',
        _ => 'Receber Bitcoin',
      };

  static String receiveKeroseneTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Receive on Kerosene',
        'es' => 'Recibir en Kerosene',
        _ => 'Receber na Kerosene',
      };

  static String receiveLightningTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Receive Lightning',
        'es' => 'Recibir Lightning',
        _ => 'Receber Lightning',
      };

  static String detailNetwork(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Network',
        'es' => 'Red',
        _ => 'Rede',
      };

  static String detailRequested(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Requested',
        'es' => 'Solicitado',
        _ => 'Solicitado',
      };

  static String detailAddress(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Address',
        'es' => 'Dirección',
        _ => 'Endereço',
      };

  static String detailInvoice(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Invoice',
        'es' => 'Factura',
        _ => 'Fatura',
      };

  static String addressCopied(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Address copied',
        'es' => 'Dirección copiada',
        _ => 'Endereço copiado',
      };

  static String invoiceCopied(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Invoice copied',
        'es' => 'Factura copiada',
        _ => 'Fatura copiada',
      };

  static String lightningSettledStatus(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Paid on Lightning',
        'es' => 'Pagado en Lightning',
        _ => 'Pago na Lightning',
      };

  static String lightningPendingStatus(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Waiting for Lightning payment',
        'es' => 'Esperando pago Lightning',
        _ => 'Aguardando pagamento Lightning',
      };

  static String paymentIdentifiedTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Payment identified',
        'es' => 'Pago identificado',
        _ => 'Pagamento identificado',
      };

  static String detailDate(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Date',
        'es' => 'Fecha',
        _ => 'Data',
      };

  static String doneAction(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Done',
        'es' => 'Listo',
        _ => 'Concluir',
      };

  static String shareReceiptHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Payment details copied',
        'es' => 'Detalles del pago copiados',
        _ => 'Detalhes do pagamento copiados',
      };

  static String prepareTrackingFailed(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Could not prepare tracking for this receive request.',
        'es' => 'No se pudo preparar el seguimiento de este cobro.',
        _ => 'Não foi possível preparar o acompanhamento deste recebimento.',
      };

  static String nfcIdMissing(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'The NFC request did not return a public identifier.',
        'es' => 'La solicitud NFC no devolvió un identificador público.',
        _ => 'A solicitação NFC não retornou um identificador público.',
      };

  static String _language(BuildContext context) =>
      Localizations.localeOf(context).languageCode;
}
