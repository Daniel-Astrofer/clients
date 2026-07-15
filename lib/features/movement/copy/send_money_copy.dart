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

  static String _language(BuildContext context) =>
      Localizations.localeOf(context).languageCode;
}
