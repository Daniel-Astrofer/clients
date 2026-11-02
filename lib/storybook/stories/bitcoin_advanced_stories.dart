import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/app/providers/session_storage_scope_provider.dart';
import 'package:storybook_flutter/storybook_flutter.dart';

import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_screens/cold_wallet_creation_screen.dart';

import '../storybook_mocks.dart';

List<Story> bitcoinAdvancedStories() {
  return [
    Story(
      name: 'Bitcoin/Advanced',
      builder: (_) => ProviderScope(
        overrides: [
          bitcoinAccountsServiceProvider.overrideWithValue(
            MockBitcoinAccountsService(),
          ),
          bitcoinAccountsByScopeProvider
              .overrideWith2(BitcoinAccountsNotifier.new),
        ],
        child: const BitcoinAccountsScreen(),
      ),
    ),
    Story(
      name: 'Bitcoin/Cards Surface',
      builder: (_) => const BitcoinCardsSurfaceStoryPreview(),
    ),
    Story(
      name: 'Bitcoin/Cold Wallet/Create Flow',
      builder: (_) => const ColdWalletCreationStoryPreview(),
    ),
  ];
}

class BitcoinCardsSurfaceStoryPreview extends StatelessWidget {
  const BitcoinCardsSurfaceStoryPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sessionStorageScopeProvider.overrideWithValue('storybook-session'),
        bitcoinAccountsServiceProvider.overrideWithValue(
          MockBitcoinAccountsService(),
        ),
        bitcoinAccountsByScopeProvider
            .overrideWith2(BitcoinAccountsNotifier.new),
        // Resolve this selector in the same scope as the preview service/session.
        bitcoinAccountsProvider.overrideWith((ref) => ref.watch(
            bitcoinAccountsByScopeProvider(
                ref.watch(sessionStorageScopeProvider)))),
      ],
      child: const BitcoinAccountsScreen(),
    );
  }
}

class ColdWalletCreationStoryPreview extends StatelessWidget {
  const ColdWalletCreationStoryPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sessionStorageScopeProvider.overrideWithValue('storybook-session'),
        bitcoinAccountsServiceProvider.overrideWithValue(
          MockBitcoinAccountsService(),
        ),
        bitcoinAccountsByScopeProvider
            .overrideWith2(BitcoinAccountsNotifier.new),
      ],
      child: ColdWalletCreationScreen(initialStepName: 'prepare'),
    );
  }
}
