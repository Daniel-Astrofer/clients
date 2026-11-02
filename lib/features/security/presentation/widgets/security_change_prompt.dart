import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/l10n_extension.dart';
import 'package:kerosene/core/services/device_key_service.dart';
import 'package:kerosene/design_system/components/generic/app_notice.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/account_security_change_factors.dart';
import 'package:kerosene/features/security/application/security_change_authorizer.dart';
import 'package:kerosene/features/security/presentation/providers/security_provider.dart';
import 'transaction_auth_gate.dart';

/// Collects the account's required factors without carrying them across owners.
Future<AccountSecurityChangeFactors?> promptSecurityChange(
    BuildContext context, WidgetRef ref, String ownerScope) async {
  bool current() =>
      context.mounted && ref.read(sessionStorageScopeProvider) == ownerScope;
  final profile = (await ref.read(accountSecurityProfileProvider.future))
      .forAccountSecurityChange();
  if (!context.mounted || !current()) return null;
  final result = await TransactionAuthGate.show(context, profile: profile);
  if (!context.mounted || !current() || result.isCancelled) return null;
  if (!result.isAuthenticated) {
    AppNotice.showInfo(context,
        title: context.tr.securityCurrentStatusTitle,
        message: context.tr.securityAuthorizationUnavailableMessage);
    return null;
  }
  try {
    return await ref.read(securityChangeAuthorizerProvider).authorize(
          expectedScope: ownerScope,
          requiresPasskey: profile.requiresPasskey,
          manualFactors: AccountSecurityChangeFactors(
            confirmationPassphrase: result.confirmationPassphrase,
            totpCode: result.totpCode,
          ),
        );
  } on DeviceKeyException catch (error) {
    if (error.code == 'ERR_AUTH_DEVICE_KEY_AUTH_CANCELLED') return null;
    rethrow;
  }
}
