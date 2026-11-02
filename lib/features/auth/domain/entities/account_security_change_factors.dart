/// Ephemeral authorization for account security changes. Never persist or log.
class AccountSecurityChangeFactors {
  final String? totpCode;
  final String? passkeyAssertionJson;
  final String? confirmationPassphrase;

  const AccountSecurityChangeFactors({
    this.totpCode,
    this.passkeyAssertionJson,
    this.confirmationPassphrase,
  });

  Map<String, dynamic> toJson() => {
        if (totpCode != null) 'totpCode': totpCode,
        if (passkeyAssertionJson != null)
          'passkeyAssertionJson': passkeyAssertionJson,
        // Spaces belong to the password; preserve the supplied value.
        if (confirmationPassphrase != null)
          'confirmationPassphrase': confirmationPassphrase,
      };
}
