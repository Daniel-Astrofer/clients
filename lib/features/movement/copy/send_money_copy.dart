import 'package:flutter/widgets.dart';

class SendMoneyCopy {
  const SendMoneyCopy._();

  static String sendTitle(BuildContext context) => switch (_language(context)) {
        'en' => 'Send',
        'es' => 'Enviar',
        _ => 'Enviar',
      };

  static String walletSelectionSubtitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Choose the source wallet for this send.',
        'es' => 'Elige la billetera de origen para este envío.',
        _ => 'Escolha a carteira de origem para este envio.',
      };

  static String walletLoadFailed(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'We could not load your wallets right now.',
        'es' => 'No pudimos cargar tus billeteras ahora.',
        _ => 'Não conseguimos carregar suas carteiras agora.',
      };

  static String walletLoadLoadingTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Loading wallets',
        'es' => 'Cargando billeteras',
        _ => 'Carregando carteiras',
      };

  static String walletLoadLoadingBody(
    BuildContext context,
    int elapsedSeconds,
  ) =>
      switch (_language(context)) {
        'en' => 'Syncing your available source wallets. ${elapsedSeconds}s',
        'es' => 'Sincronizando tus billeteras disponibles. ${elapsedSeconds}s',
        _ => 'Sincronizando suas carteiras disponíveis. ${elapsedSeconds}s',
      };

  static String walletLoadSlowTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Still loading wallets',
        'es' => 'Aún cargando billeteras',
        _ => 'Ainda carregando carteiras',
      };

  static String walletLoadSlowBody(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'This is taking longer than expected. Check your connection or try again.',
        'es' =>
          'Esto está tardando más de lo esperado. Revisa tu conexión o intenta otra vez.',
        _ =>
          'Isso está demorando mais que o esperado. Verifique sua conexão ou tente novamente.',
      };

  static String noWalletsForSend(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'No wallets available for sending were found.',
        'es' => 'No encontramos billeteras disponibles para enviar.',
        _ => 'Não encontramos carteiras disponíveis para envio.',
      };

  static String chooseWalletToContinue(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Choose a wallet to continue.',
        'es' => 'Elige una billetera para continuar.',
        _ => 'Escolha uma carteira para continuar.',
      };

  static String destinationTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Who would you like to send to?',
        'es' => '¿A quién deseas enviar?',
        _ => 'Para quem deseja enviar?',
      };

  static String destinationHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Username, Bitcoin address, or link',
        'es' => 'Usuario, dirección Bitcoin o link',
        _ => 'Usuário, endereço Bitcoin ou link',
      };

  static String unrecognizedDestination(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'We do not recognize this destination. Review it or choose another format.',
        'es' => 'No reconocemos este destino. Revísalo o elige otro formato.',
        _ => 'Não reconhecemos esse destino. Revise ou escolha outro formato.',
      };

  static String insufficientBalance(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'This wallet balance does not cover the send.',
        'es' => 'El saldo de esta billetera no cubre el envío.',
        _ => 'O saldo desta carteira não cobre o envio.',
      };

  static String frequentDestinations(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Frequent destinations',
        'es' => 'Destinos frecuentes',
        _ => 'Destinos frequentes',
      };

  static String allDestinations(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'All destinations',
        'es' => 'Todos los destinos',
        _ => 'Todos os destinos',
      };

  static String noRecentDestinations(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'No recent destinations yet.',
        'es' => 'Aún no hay destinos recientes.',
        _ => 'Nenhum destino recente ainda.',
      };

  static String noRecentDestinationsBody(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Enter a username, address, or link to start your first send.',
        'es' =>
          'Informa un usuario, dirección o link para iniciar tu primer envío.',
        _ =>
          'Informe um usuário, endereço ou link para iniciar seu primeiro envio.',
      };

  static String networkFeeUnavailable(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'We could not calculate the network fee right now. Try again.',
        'es' =>
          'No pudimos calcular la tarifa de red ahora. Inténtalo de nuevo.',
        _ => 'Não conseguimos calcular a taxa de rede agora. Tente novamente.',
      };

  static String onchainSendDescription(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'On-chain send',
        'es' => 'Envío on-chain',
        _ => 'Envio on-chain',
      };

  static String offlineBanner(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'No connection — reconnect to send.',
        'es' => 'Sin conexión — reconéctate para enviar.',
        _ => 'Sem conexão — reconecte para enviar.',
      };

  static String offlineBlocked(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'You are offline. Check your connection and try again.',
        'es' => 'Estás sin conexión. Revisa la red e inténtalo de nuevo.',
        _ => 'Você está offline. Verifique a conexão e tente de novo.',
      };

  static String coldSeedMissing(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'No backup on this device. Restore the cold wallet BIP39 seed to sign.',
        'es' =>
          'Sin copia en este dispositivo. Restaura la seed BIP39 de la cold para firmar.',
        _ =>
          'Sem backup neste aparelho. Restaure a seed BIP39 da carteira fria para assinar.',
      };

  static String coldOnlyOnchain(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'Cold wallets only send on-chain. Use a Bitcoin address (tb1…/bc1…).',
        'es' =>
          'La cold solo envía on-chain. Usa una dirección Bitcoin (tb1…/bc1…).',
        _ =>
          'Carteira fria envia só on-chain. Use um endereço Bitcoin (tb1…/bc1…).',
      };

  static String coldNoLightning(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Cold wallets cannot send Lightning. Use an on-chain address.',
        'es' =>
          'La cold no envía Lightning. Usa una dirección on-chain.',
        _ => 'Carteira fria não envia Lightning. Use um endereço on-chain.',
      };

  static String coldNoPaymentLink(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'Cold wallets cannot pay Kerosene links via the ledger. Use an on-chain address.',
        'es' =>
          'La cold no paga links de Kerosene por el ledger. Usa una dirección on-chain.',
        _ =>
          'Carteira fria não paga link Kerosene pelo ledger. Use um endereço on-chain.',
      };

  static String coldNoInternal(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'Cold wallets cannot send internal Kerosene transfers. Use an on-chain address.',
        'es' =>
          'La cold no envía transferencias internas. Usa una dirección on-chain.',
        _ =>
          'Carteira fria não faz transferência interna. Use um endereço on-chain.',
      };

  static String sendSuccessTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Send submitted',
        'es' => 'Envío enviado',
        _ => 'Envio enviado',
      };

  static String sendSuccessBody(
    BuildContext context, {
    required String amountLabel,
    required String destinationLabel,
  }) =>
      switch (_language(context)) {
        'en' => 'Sent $amountLabel to $destinationLabel.',
        'es' => 'Enviaste $amountLabel a $destinationLabel.',
        _ => 'Enviado $amountLabel para $destinationLabel.',
      };

  static String progressResolving(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Checking how the recipient can receive…',
        'es' => 'Comprobando cómo puede recibir el destinatario…',
        _ => 'Verificando como o destinatário pode receber…',
      };

  static String progressAuthorizing(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Authorizing…',
        'es' => 'Autorizando…',
        _ => 'Autorizando…',
      };

  static String progressSigningDevice(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Signing on this device…',
        'es' => 'Firmando en este dispositivo…',
        _ => 'Assinando no aparelho…',
      };

  static String progressSending(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Sending…',
        'es' => 'Enviando…',
        _ => 'Enviando…',
      };

  // --- Amount step context (bank sticky party) ---

  static String amountToTitle(BuildContext context, String recipient) {
    final clean = recipient.trim();
    if (clean.isEmpty) {
      return switch (_language(context)) {
        'en' => 'Amount',
        'es' => 'Monto',
        _ => 'Valor',
      };
    }
    return switch (_language(context)) {
      'en' => 'To $clean',
      'es' => 'Para $clean',
      _ => 'Para $clean',
    };
  }

  static String amountFromSubtitle(BuildContext context, String walletName) {
    final clean = walletName.trim();
    if (clean.isEmpty) return '';
    return switch (_language(context)) {
      'en' => 'From $clean',
      'es' => 'Desde $clean',
      _ => 'De $clean',
    };
  }

  // --- Destination type feedback ---

  static String destinationEmptyHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Enter a destination to continue.',
        'es' => 'Ingresa un destino para continuar.',
        _ => 'Informe o destino para continuar.',
      };

  static String destinationInvalidHint(BuildContext context) =>
      switch (_language(context)) {
        'en' =>
          'Fix the destination: Kerosene user, Bitcoin address, Lightning invoice, or link — or use QR / NFC / paste.',
        'es' =>
          'Corrige el destino: usuario Kerosene, dirección Bitcoin, invoice Lightning o link — o usa QR / NFC / pegar.',
        _ =>
          'Corrija o destino: usuário Kerosene, endereço Bitcoin, invoice Lightning, link — ou use QR / NFC / colar.',
      };

  static String destinationPaymentLinkHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Kerosene payment link detected.',
        'es' => 'Link de pago Kerosene detectado.',
        _ => 'Link de pagamento Kerosene detectado.',
      };

  static String destinationInternalHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Internal Kerosene transfer detected.',
        'es' => 'Transferencia interna Kerosene detectada.',
        _ => 'Transferência interna Kerosene detectada.',
      };

  static String destinationOnchainHint(BuildContext context, String network) =>
      switch (_language(context)) {
        'en' => 'Bitcoin on-chain address detected · $network.',
        'es' => 'Dirección Bitcoin on-chain detectada · $network.',
        _ => 'Endereço Bitcoin on-chain detectado · $network.',
      };

  static String destinationLightningHint(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Lightning payment detected.',
        'es' => 'Pago Lightning detectado.',
        _ => 'Pagamento Lightning detectado.',
      };

  // --- Review / auth soft copy ---

  static String reviewTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Does this look right?',
        'es' => '¿Está todo correcto?',
        _ => 'Confere essa transferência?',
      };

  static String authorizeAction(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Authorize',
        'es' => 'Autorizar',
        _ => 'Autorizar',
      };

  static String authorizingAction(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Authorizing…',
        'es' => 'Autorizando…',
        _ => 'Autorizando…',
      };

  /// Progressive labels while the authorize button waits on the network.
  static String authorizingPhase(BuildContext context, int phaseIndex) {
    final phases = switch (_language(context)) {
      'en' => const [
          'Authorizing…',
          'Securing…',
          'Broadcasting…',
          'Almost done…',
        ],
      'es' => const [
          'Autorizando…',
          'Protegiendo…',
          'Transmitiendo…',
          'Casi listo…',
        ],
      _ => const [
          'Autorizando…',
          'Protegendo…',
          'Transmitindo…',
          'Quase lá…',
        ],
    };
    if (phases.isEmpty) return authorizingAction(context);
    final i = phaseIndex < 0 ? 0 : phaseIndex % phases.length;
    return phases[i];
  }

  static String firstSendAckTitle(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'New address',
        'es' => 'Dirección nueva',
        _ => 'Endereço novo',
      };

  static String firstSendAckBody(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'First time sending here. Check the characters carefully.',
        'es' => 'Primera vez enviando aquí. Revisa los caracteres con cuidado.',
        _ =>
          'Primeira vez enviando para este endereço. Confira os caracteres com cuidado.',
      };

  static String firstSendAckCheckbox(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'I confirm this address',
        'es' => 'Confirmo esta dirección',
        _ => 'Confirmo este endereço',
      };

  static String authNextDevicePin(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Next: app PIN',
        'es' => 'Siguiente: PIN de la app',
        _ => 'Em seguida: PIN do app',
      };

  static String authNextPinAndTotp(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Next: app PIN · authenticator',
        'es' => 'Siguiente: PIN de la app · autenticador',
        _ => 'Em seguida: PIN do app · autenticador',
      };

  static String receiptSubtitleConfirmed(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Completed',
        'es' => 'Completada',
        _ => 'Concluída',
      };

  static String receiptSubtitlePending(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Submitted · waiting for network',
        'es' => 'Enviada · esperando la red',
        _ => 'Enviada · aguardando a rede',
      };

  static String reviewDetailsLabel(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Details',
        'es' => 'Detalles',
        _ => 'Detalhes',
      };

  static String destinationScanAction(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Scan QR',
        'es' => 'Escanear QR',
        _ => 'Escanear QR',
      };

  static String destinationTipInternal(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Kerosene user · instant',
        'es' => 'Usuario Kerosene · instantáneo',
        _ => 'Usuário Kerosene · instantâneo',
      };

  static String destinationTipLightning(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Lightning invoice',
        'es' => 'Invoice Lightning',
        _ => 'Invoice Lightning',
      };

  static String destinationTipOnchain(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Bitcoin address · on-chain',
        'es' => 'Dirección Bitcoin · on-chain',
        _ => 'Endereço Bitcoin · on-chain',
      };

  static String networkLabel(
    BuildContext context, {
    required bool isPaymentLink,
    required bool isLightning,
    required bool isOnChain,
  }) {
    if (isPaymentLink) {
      return switch (_language(context)) {
        'en' => 'Internal link',
        'es' => 'Link interno',
        _ => 'Link interno',
      };
    }
    if (isLightning) return 'Lightning';
    if (isOnChain) return 'On-chain';
    return 'Kerosene';
  }

  static String networkRowLabel(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Network',
        'es' => 'Red',
        _ => 'Rede',
      };

  static String signatureRowLabel(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Signature',
        'es' => 'Firma',
        _ => 'Assinatura',
      };

  static String signatureOnDevice(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'On this device · local seed',
        'es' => 'En este dispositivo · seed local',
        _ => 'No aparelho · seed local',
      };

  static String feeFree(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Free',
        'es' => 'Gratis',
        _ => 'Grátis',
      };

  static String feeEstimatedAtPayment(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Estimated at payment',
        'es' => 'Estimada al pagar',
        _ => 'Estimada no pagamento',
      };

  static String feeCalculating(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Calculating…',
        'es' => 'Calculando…',
        _ => 'Calculando…',
      };

  static String feeTierFast(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Fast',
        'es' => 'Rápido',
        _ => 'Rápido',
      };

  static String feeTierSlow(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Economy',
        'es' => 'Económico',
        _ => 'Econômico',
      };

  static String feeTierStandard(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Standard',
        'es' => 'Normal',
        _ => 'Normal',
      };

  static String reviewNotePaymentLink(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Payment via internal link',
        'es' => 'Pago por link interno',
        _ => 'Pagamento por link interno',
      };

  static String reviewNoteLightning(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Lightning payment',
        'es' => 'Pago Lightning',
        _ => 'Pagamento Lightning',
      };

  static String reviewNoteOnchainCold(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'You sign on-device · Kerosene only observes the chain',
        'es' => 'Firmas en el dispositivo · Kerosene solo observa la cadena',
        _ => 'Você assina no aparelho · Kerosene só observa a blockchain',
      };

  static String reviewNoteOnchain(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'On-chain send',
        'es' => 'Envío on-chain',
        _ => 'Envio on-chain',
      };

  static String reviewNoteInternal(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Internal Kerosene transfer',
        'es' => 'Transferencia interna Kerosene',
        _ => 'Transferência interna Kerosene',
      };

  // --- Receipt / success ---

  static String receiptTitleConfirmed(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Transfer complete',
        'es' => 'Transferencia completada',
        _ => 'Transferência concluída',
      };

  static String receiptTitleSubmitted(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Transfer sent',
        'es' => 'Transferencia enviada',
        _ => 'Transferência enviada',
      };

  static String receiptDateLabel(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Date',
        'es' => 'Fecha',
        _ => 'Data',
      };

  static String receiptShareAction(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Share receipt',
        'es' => 'Compartir comprobante',
        _ => 'Compartilhar comprovante',
      };

  static String receiptDoneAction(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Done',
        'es' => 'Listo',
        _ => 'Concluir',
      };

  static String receiptCopied(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Receipt copied',
        'es' => 'Comprobante copiado',
        _ => 'Comprovante copiado',
      };

  static String receiptShareAmount(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Amount',
        'es' => 'Monto',
        _ => 'Valor',
      };

  static String closeTooltip(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Close',
        'es' => 'Cerrar',
        _ => 'Fechar',
      };

  static String networkMismatch(
    BuildContext context, {
    required String detected,
    required String expected,
  }) =>
      switch (_language(context)) {
        'en' =>
          'Address network ($detected) does not match the app network ($expected).',
        'es' =>
          'La red de la dirección ($detected) no coincide con la del app ($expected).',
        _ =>
          'Rede do endereço ($detected) não confere com a rede do app ($expected).',
      };

  static String detailFrom(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'From',
        'es' => 'De',
        _ => 'De',
      };

  static String detailTo(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'To',
        'es' => 'Para',
        _ => 'Para',
      };

  static String detailWhen(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'When',
        'es' => 'Cuándo',
        _ => 'Quando',
      };

  static String detailYourWallet(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Your wallet',
        'es' => 'Tu billetera',
        _ => 'Sua carteira',
      };

  static String detailTechnical(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Technical details',
        'es' => 'Detalles técnicos',
        _ => 'Detalhes técnicos',
      };

  static String detailExplorer(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Explorer',
        'es' => 'Explorador',
        _ => 'Explorer',
      };

  static String detailStatusConfirming(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Confirming',
        'es' => 'Confirmando',
        _ => 'Confirmando',
      };

  static String detailStatusCancelled(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Cancelled',
        'es' => 'Cancelada',
        _ => 'Cancelada',
      };

  static String detailStatusFailed(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Failed',
        'es' => 'Falló',
        _ => 'Falhou',
      };

  static String detailStatusReconciling(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Under review',
        'es' => 'En revisión',
        _ => 'Em revisão',
      };

  static String destinationKindInternal(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Internal transfer',
        'es' => 'Transferencia interna',
        _ => 'Transferência interna',
      };

  static String destinationKindOnchain(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'On-chain address',
        'es' => 'Dirección on-chain',
        _ => 'Endereço on-chain',
      };

  static String destinationKindLightning(BuildContext context) =>
      switch (_language(context)) {
        'en' => 'Lightning invoice',
        'es' => 'Invoice Lightning',
        _ => 'Invoice Lightning',
      };

  static String _language(BuildContext context) =>
      Localizations.localeOf(context).languageCode;
}
