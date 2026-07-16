import 'package:kerosene/core/l10n/app_localizations.dart';

/// @nodoc
///
/// Legacy static Portuguese copy. **Do not add new strings here.**
/// All keys live in ARB (`context.tr`). This facade keeps older call sites
/// compiling while they migrate to [AppLocalizations].
@Deprecated('Use context.tr / AppLocalizations from ARB instead')
class KeroseneUiCopy {
  const KeroseneUiCopy._();

  static String goBack(AppLocalizations l10n) => l10n.goBack;
  static String cancel(AppLocalizations l10n) => l10n.cancel;
  static String cancelOperation(AppLocalizations l10n) => l10n.cancelOperation;
  static String cancelAuthentication(AppLocalizations l10n) =>
      l10n.cancelAuthentication;
  static String deposit(AppLocalizations l10n) => l10n.deposit;
  static String secureConnectionLoading(AppLocalizations l10n) =>
      l10n.secureConnectionLoading;
  static String deferredLoadFailure(AppLocalizations l10n) =>
      l10n.deferredLoadFailure;
  static String deferredLoadDetails(AppLocalizations l10n) =>
      l10n.deferredLoadDetails;
  static String nfcScannerTitle(AppLocalizations l10n) => l10n.nfcScannerTitle;
  static String nfcReadyToScan(AppLocalizations l10n) => l10n.nfcReadyToScan;
  static String nfcUnavailable(AppLocalizations l10n) =>
      l10n.nfcUnavailableDevice;
  static String nfcHoldNearTag(AppLocalizations l10n) => l10n.nfcHoldNearTag;
  static String nfcPaymentRequestRead(AppLocalizations l10n) =>
      l10n.nfcPaymentRequestRead;
  static String nfcTagDetected(AppLocalizations l10n) => l10n.nfcTagDetected;
  static String offlineTitle(AppLocalizations l10n) => l10n.offlineTitle;
  static String offlineSubtitle(AppLocalizations l10n) => l10n.offlineSubtitle;
  static String offlineRetryHint(AppLocalizations l10n) => l10n.offlineRetryHint;
  static String pinIncorrect(AppLocalizations l10n) => l10n.pinIncorrect;
  static String pinSetupTitle(AppLocalizations l10n) => l10n.pinSetupTitle;
  static String pinEnterTitle(AppLocalizations l10n) => l10n.pinEnterTitle;
  static String pinSetupSubtitle(AppLocalizations l10n) => l10n.pinSetupSubtitle;
  static String pinEnterSubtitle(AppLocalizations l10n) => l10n.pinEnterSubtitle;
}
