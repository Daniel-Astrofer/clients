import 'package:flutter/material.dart';
import 'package:kerosene/features/financial_accounts/presentation/financial_hub_flow/financial_hub_screen.dart';

/// Compatibility entry point for account routes and stories.
///
/// The account experience is owned by [FinancialHubScreen]. Keeping this
/// small adapter preserves existing routes while preventing the legacy account
/// surface from being duplicated here.
class BitcoinAccountsScreen extends StatelessWidget {
  const BitcoinAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => const FinancialHubScreen();
}
