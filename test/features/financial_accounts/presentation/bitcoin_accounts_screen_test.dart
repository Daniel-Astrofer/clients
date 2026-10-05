import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/bitcoin_account_models.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/bitcoin_accounts_screen.dart';

void main() {
  testWidgets('routes the compatibility entry point to the financial hub',
      (tester) async {
    await _pumpAccounts(tester, const [_internalAccount]);
    await tester.pumpAndSettle();

    expect(find.text('Saldo Atual'), findsOneWidget);
    expect(find.byType(BitcoinAccountsScreen), findsOneWidget);
  });

  testWidgets('renders the dedicated empty financial accounts layout',
      (tester) async {
    await _pumpAccounts(tester, const []);
    await tester.pumpAndSettle();

    expect(find.text('Contas Bitcoin'), findsOneWidget);
    expect(find.text('Nenhuma conta Bitcoin ainda'), findsOneWidget);
    expect(find.text('Novo cartão Kerosene'), findsOneWidget);
    expect(find.text('Criar Cold Wallet'), findsOneWidget);
  });
}

Future<void> _pumpAccounts(
  WidgetTester tester,
  List<BitcoinAccount> accounts,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bitcoinAccountsProvider.overrideWith(
          () => _AccountsNotifier(accounts),
        ),
        authControllerProvider.overrideWith(() => _AuthTestController()),
        sessionStorageScopeProvider.overrideWithValue('test-user'),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BitcoinAccountsScreen(),
      ),
    ),
  );
}

class _AccountsNotifier extends BitcoinAccountsNotifier {
  final List<BitcoinAccount> _accounts;

  _AccountsNotifier(List<BitcoinAccount> accounts)
      : _accounts = List<BitcoinAccount>.unmodifiable(accounts);

  @override
  Future<List<BitcoinAccount>> build() async => _accounts;
}

class _AuthTestController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(
        User(
          id: 'user-1',
          username: 'Satoshi Nakamoto',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
}

const _internalAccount = BitcoinAccount(
  id: 'internal-1',
  type: 'INTERNAL_CARD',
  custody: 'KEROSENE_CUSTODIAL',
  status: 'ACTIVE',
  label: 'Internal BTC Card',
  riskTier: 'BRONZE',
  cardId: 'card-1',
  balanceAvailableSats: 125000,
);
