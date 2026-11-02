import 'package:flutter/material.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';

String signupCreateAccountTitle(BuildContext context) =>
    context.tr.flowSignupCreateAccountTitle;

String signupUsernameSubtitle(BuildContext context) =>
    context.tr.flowSignupUsernameSubtitle;

String signupUsernameHint(BuildContext context) =>
    context.tr.flowSignupUsernameHint;

String signupUsernameCharsetRule(BuildContext context) =>
    context.tr.flowSignupUsernameCharsetRule;

String signupPassphraseTitle(BuildContext context) =>
    context.tr.flowSignupPassphraseTitle;

String signupPassphraseSubtitle(BuildContext context) =>
    context.tr.flowSignupPassphraseSubtitle;

String signupPassphraseLabel(BuildContext context) =>
    context.tr.flowSignupPassphraseLabel;

String signupPassphraseHint(BuildContext context) =>
    context.tr.flowSignupPassphraseHint;

String signupProceedAction(BuildContext context) =>
    context.tr.flowSignupProceedAction;

String signupConfirmTitle(BuildContext context) =>
    context.tr.flowSignupConfirmTitle;

String signupConfirmSubtitle(BuildContext context) =>
    context.tr.flowSignupConfirmSubtitle;

String signupConfirmHint(BuildContext context) =>
    context.tr.flowSignupConfirmHint;

String signupFinishCreateAccountAction(BuildContext context) =>
    context.tr.flowSignupFinishCreateAccountAction;

String signupCreatingAlmostReadyTitle(BuildContext context) =>
    context.tr.flowSignupCreatingAlmostReadyTitle;

String signupCreatingAlmostReadySubtitle(BuildContext context) =>
    context.tr.flowSignupCreatingAlmostReadySubtitle;

String signupCreatingSecurityProgress(BuildContext context) =>
    context.tr.flowSignupCreatingSecurityProgress;

String signupTotpTitle(BuildContext context) => context.tr.flowSignupTotpTitle;

String signupTotpSubtitle(BuildContext context) =>
    context.tr.flowSignupTotpSubtitle;

String signupRecoveryCodesTitle(BuildContext context) =>
    context.tr.flowSignupRecoveryCodesTitle;

String signupTotpCodeInstruction(BuildContext context) =>
    context.tr.flowSignupTotpCodeInstruction;

String signupRecoveryCodesCopiedMessage(BuildContext context) =>
    context.tr.flowSignupRecoveryCodesCopiedMessage;

String signupRecoveryCodesUnavailableTitle(BuildContext context) =>
    context.tr.flowSignupRecoveryCodesUnavailableTitle;

String signupRecoveryCodesUnavailableMessage(BuildContext context) =>
    context.tr.flowSignupRecoveryCodesUnavailableMessage;

String signupSkipAction(BuildContext context) =>
    context.tr.flowSignupSkipAction;

String signupConfirmAction(BuildContext context) =>
    context.tr.flowSignupConfirmAction;

String signupPasskeyTitle(BuildContext context) =>
    context.tr.flowSignupPasskeyTitle;

String signupPasskeySubtitle(BuildContext context) =>
    context.tr.flowSignupPasskeySubtitle;

String signupAuthorizeDeviceAction(BuildContext context) =>
    context.tr.flowSignupAuthorizeDeviceAction;

String signupSuccessBody(BuildContext context) =>
    context.tr.flowSignupSuccessBody;

String signupStartAction(BuildContext context) =>
    context.tr.flowSignupStartAction;

String _signupCopy(BuildContext context, String pt, String en, String es) =>
    switch (Localizations.localeOf(context).languageCode) {
      'en' => en,
      'es' => es,
      _ => pt,
    };

String signupConfirmingPasskeyTitle(BuildContext context) => _signupCopy(
      context,
      'Confirmando passkey',
      'Confirming passkey',
      'Confirmando passkey',
    );

String signupConfirmingPasskeySubtitle(BuildContext context) => _signupCopy(
      context,
      'Confirme com a biometria ou o bloqueio de tela do seu dispositivo.',
      'Confirm using biometrics or your device screen lock.',
      'Confirma con la biometría o el bloqueo de pantalla de tu dispositivo.',
    );

String signupPasskeyRequiredBody(BuildContext context) => _signupCopy(
      context,
      'Sua passkey é obrigatória para concluir o cadastro. A confirmação é feita com segurança pelo seu dispositivo.',
      'A passkey is required to complete sign-up. Your device handles confirmation securely.',
      'Tu passkey es obligatoria para completar el registro. Tu dispositivo realiza la confirmación de forma segura.',
    );

String signupSetupNextBody(BuildContext context) => _signupCopy(
      context,
      'Sua conta está protegida. Agora crie seu PIN de 4 dígitos e escolha como começar.',
      'Your account is protected. Now create your 4-digit PIN and choose how to get started.',
      'Tu cuenta está protegida. Ahora crea tu PIN de 4 dígitos y elige cómo empezar.',
    );

String signupProgressSaveError(BuildContext context) => _signupCopy(
      context,
      'Não foi possível salvar esta etapa no dispositivo. Tente continuar novamente.',
      'We could not save this step on your device. Try continuing again.',
      'No se pudo guardar esta etapa en tu dispositivo. Intenta continuar de nuevo.',
    );
