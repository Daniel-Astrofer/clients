import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/core/providers/price_provider.dart';
import 'package:kerosene/core/providers/shared_preferences_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/financial_accounts/presentation/state/wallet_state.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen.dart';
import 'package:kerosene/features/home/presentation/screens/home_screen_balance.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home balance starts on total and swipes to internal wallet',
      (tester) async {
    await _pumpBalance(tester, wallets: [_wallet(name: 'Carteira Global')]);

    expect(find.text('SALDO'), findsNothing);
    expect(
        find.byKey(const ValueKey('home-balance-hero-total')), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('home-balance-hero-platform')),
        findsOneWidget);
    expect(find.text('Carteira Global'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('home tabs list platform and cofre environments', (tester) async {
    await _pumpBalance(
      tester,
      wallets: [
        _wallet(name: 'Carteira Global', balance: 0.1),
        _wallet(
          id: 'wallet-cold',
          name: 'Cold vault',
          walletMode: 'WATCH_ONLY',
          balance: 0.2,
        ),
      ],
    );

    expect(find.text('SALDO'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('home-balance-hero-platform')),
        findsOneWidget);
    expect(find.text('Carteira Global'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
        find.byKey(const ValueKey('home-balance-hero-cold')), findsOneWidget);
    expect(find.text('Cold vault'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _pumpBalance(
  WidgetTester tester, {
  required List<Wallet> wallets,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  SharedPreferences.setMockInitialValues(const {});
  final sharedPreferences = await SharedPreferences.getInstance();
  final walletState = WalletLoaded(
    wallets: wallets,
    selectedWallet: wallets.firstOrNull,
    btcToUsdRate: 65000,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        sessionNotificationFeedProvider.overrideWith(
          () => _EmptyNotificationFeedNotifier(),
        ),
        latestBtcPriceProvider.overrideWith((ref) => 65000),
        btcEurPriceProvider.overrideWith((ref) => 60000),
        btcBrlPriceProvider.overrideWith((ref) => 350000),
        btcDailyChangePercentProvider.overrideWith((ref) => 0),
        homeRouteActiveProvider.overrideWith((ref) => false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: SingleChildScrollView(
              child: HomeBalanceSection(
                userName: 'Satoshi',
                walletState: walletState,
                activeWallet: wallets.firstOrNull,
                onReceive: () {},
                onSend: () {},
                onViewStatement: () {},
                onOpenWallets: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Wallet _wallet({
  String id = 'wallet-global',
  required String name,
  String walletMode = 'INTERNAL',
  double balance = 0.1,
}) {
  return Wallet(
    id: id,
    name: name,
    address: 'kerosene:$id',
    walletMode: walletMode,
    balance: balance,
    derivationPath: "m/84'/0'/0'/0/0",
    type: WalletType.nativeSegwit,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}

class _EmptyNotificationFeedNotifier extends SessionNotificationFeedNotifier {
  @override
  List<SessionNotificationItem> build() => const [];
}
