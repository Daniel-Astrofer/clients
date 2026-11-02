import 'package:kerosene/design_system/foundation/theme/kerosene_ui_scale.dart';
import 'dart:async';
import 'package:dartz/dartz.dart' show Either, Right;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/presentation/hub/receive_gateway_providers_screen.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart'
    show sessionStorageScopeProvider;
import 'package:kerosene/design_system/components/buttons/app_button.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/features/movement/data/repositories/transaction_repository.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart'
    show transactionRepositoryProvider;

const _checkout =
    'https://pagamentos.example/checkout?invoice=fixture123&amount=250.50&currency=BRL';
const _launcher = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher, null);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AppScreenFeedbackBus.clear();
  });

  test('links provider discards the old response when the account changes',
      () async {
    final repository = _GatewayRepository();
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider
          .overrideWith((ref) => ref.watch(gatewayTestSessionProvider)),
      transactionRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container
        .listen(receiveGatewayLinksProvider, (_, __) {}, fireImmediately: true);
    addTearDown(subscription.close);
    await container.pump();
    expect(repository.requests, hasLength(1));
    container.read(gatewayTestSessionProvider.notifier).change('account-b');
    await container.pump();
    expect(repository.requests, hasLength(2));
    repository.requests.last.complete(
        const Right({'New provider': 'https://new.example/checkout'}));
    await container.read(receiveGatewayLinksProvider.future);
    repository.requests.first.complete(
        const Right({'Old provider': 'https://old.example/checkout'}));
    await container.pump();
    expect(container.read(receiveGatewayLinksProvider).requireValue.urls,
        {'New provider': 'https://new.example/checkout'});
  });

  test('links provider does not query without an active account', () async {
    final repository = _GatewayRepository();
    final container = ProviderContainer(overrides: [
      sessionStorageScopeProvider.overrideWithValue(null),
      transactionRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await expectLater(container.read(receiveGatewayLinksProvider.future),
        throwsA(isA<StateError>()));
    expect(repository.requests, isEmpty);
  });

  testWidgets('configured providers include unknown names without fake terms',
      (tester) async {
    await pumpGateway(tester,
        load: () async => gatewaySnapshot(
            {'Mercado Pago': _checkout, 'Outro vendedor': _checkout}));
    expect(find.text('Mercado Pago'), findsOneWidget);
    expect(find.text('Outro vendedor'), findsOneWidget);
    expect(find.textContaining('Links consultados em'), findsOneWidget);
    expect(find.text('MoonPay'), findsNothing);
    expect(find.textContaining('Instantâneo'), findsNothing);
    expect(find.textContaining('1%'), findsNothing);
  });

  for (final variant in AppThemeVariant.values) {
    testWidgets('checkout shows full data at large scale: $variant',
        (tester) async {
      await pumpGateway(tester,
          variant: variant,
          scale: 1.8,
          load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
      await tester.ensureVisible(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SelectableText, _checkout), findsOneWidget);
      expect(find.widgetWithText(SelectableText, gatewayWallet().id),
          findsOneWidget);
      expect(find.textContaining('não confirma a carteira de destino'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      final route = ModalRoute.of(
          tester.element(find.byKey(const ValueKey('gateway-open-checkout'))));
      expect(route!.transitionDuration, Duration.zero);
    });
  }

  testWidgets('opening preserves checkout and never acknowledges payment',
      (tester) async {
    final result = Completer<bool>();
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher,
        (call) async {
      calls.add(call);
      return result.future;
    });
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.tap(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('gateway-open-checkout')));
    expect(calls, hasLength(1));
    expect(calls.single.arguments['url'], _checkout);
    expect(calls.single.arguments['useWebView'], false);
    expect(calls.single.arguments['useSafariVC'], false);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('foi aberto'), findsOneWidget);
    expect(find.textContaining('não confirma o pagamento'), findsOneWidget);
    expect(
        AppScreenFeedbackBus.current.value?.type, isNot(AppNoticeType.success));
    expect(tester.takeException(), isNull);
  });

  for (final throws in [false, true]) {
    testWidgets('failed launch remains retryable (throws: $throws)',
        (tester) async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher,
          (_) async {
        if (throws) throw PlatformException(code: 'unavailable');
        return false;
      });
      await pumpGateway(tester,
          load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
      await tester.tap(find.text('Mercado Pago'));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('gateway-open-checkout')));
      await tester.tap(find.byKey(const ValueKey('gateway-open-checkout')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não conseguimos abrir o provedor'),
          findsOneWidget);
      expect(find.textContaining('foi aberto'), findsNothing);
      expect(find.text('Abrir provedor'), findsOneWidget);
    });
  }

  testWidgets('unsafe links do not offer a checkout', (tester) async {
    var launches = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher,
        (_) async {
      launches++;
      return true;
    });
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({
              'Sem TLS': 'http://pagamentos.example/pay',
              'Com credenciais': 'https://name:password@pagamentos.example/pay',
              'Aplicativo': 'javascript:alert(1)',
              'Espaço': 'https://pagamentos.example/a b',
            }));
    await tester.tap(find.text('Sem TLS'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gateway-open-checkout')), findsNothing);
    expect(launches, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh retains timestamp and data but disables checkout',
      (tester) async {
    var loads = 0;
    final container = await pumpGateway(tester, load: () async {
      if (++loads > 1) throw Exception('offline');
      return gatewaySnapshot({'Mercado Pago': _checkout});
    });
    container.invalidate(receiveGatewayLinksProvider);
    await tester.pumpAndSettle();
    expect(find.text('Mercado Pago'), findsOneWidget);
    expect(find.textContaining('última consulta'), findsOneWidget);
    expect(find.textContaining('Links consultados em'), findsOneWidget);
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gateway-open-checkout')), findsNothing);
  });

  testWidgets('empty catalog has explicit state', (tester) async {
    await pumpGateway(tester, load: () async => gatewaySnapshot({}));
    expect(find.textContaining('Nenhum provedor de compra'), findsOneWidget);
  });

  testWidgets('initial failure has an explicit retry state', (tester) async {
    await pumpGateway(tester, load: () async => throw Exception('offline'));
    expect(find.textContaining('Não foi possível carregar os provedores'),
        findsOneWidget);
    expect(find.text('Atualizar links'), findsOneWidget);
  });

  testWidgets('clipboard failure produces no copied success', (tester) async {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'denied');
      }
      return null;
    });
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-copy-checkout')));
    await tester.tap(find.byKey(const ValueKey('gateway-copy-checkout')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível copiar'), findsOneWidget);
    expect(AppScreenFeedbackBus.current.value, isNull);
  });

  testWidgets('copy success waits for clipboard acknowledgement',
      (tester) async {
    final copied = Completer<void>();
    String? value;
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        value = call.arguments['text'] as String;
        await copied.future;
      }
      return null;
    });
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-copy-checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gateway-copy-checkout')));
    await tester.pump();
    expect(value, _checkout);
    expect(AppScreenFeedbackBus.current.value, isNull);
    copied.complete();
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value?.message,
        'Link de checkout copiado.');
    await tester.pump(const Duration(seconds: 4));
    expect(AppScreenFeedbackBus.current.value, isNull);
  });

  testWidgets('late launch acknowledgement survives closing the details',
      (tester) async {
    final launched = Completer<bool>();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, (_) => launched.future);
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.pump();
    Navigator.of(
            tester.element(find.byKey(const ValueKey('gateway-open-checkout'))))
        .pop();
    await tester.pumpAndSettle();
    launched.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('foi aberto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('launch acknowledgement closes only its own route',
      (tester) async {
    final launched = Completer<bool>();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, (_) => launched.future);
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.pump();
    unawaited(showDialog<void>(
      context:
          tester.element(find.byKey(const ValueKey('gateway-open-checkout'))),
      builder: (_) => const AlertDialog(content: Text('Outro aviso')),
    ));
    await tester.pump();
    launched.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Outro aviso'), findsOneWidget);
    Navigator.of(tester.element(find.text('Outro aviso'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('gateway-open-checkout')), findsNothing);
    expect(find.textContaining('foi aberto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchase without a session exposes no wallet or checkout',
      (tester) async {
    var calls = 0;
    await pumpGateway(tester, scope: null, load: () async {
      calls++;
      return gatewaySnapshot({'Mercado Pago': _checkout});
    });
    expect(calls, 0);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    expect(find.text('Carteira principal'), findsNothing);
    expect(find.text('Mercado Pago'), findsNothing);
  });

  testWidgets('account change hides the catalog and never reuses it on return',
      (tester) async {
    final container = await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    container.read(gatewayTestSessionProvider.notifier).change('account-b');
    await tester.pumpAndSettle();
    expect(find.text('Mercado Pago'), findsNothing);
    expect(find.text('Carteira principal'), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    container.read(gatewayTestSessionProvider.notifier).change('account-a');
    await tester.pumpAndSettle();
    expect(find.text('Mercado Pago'), findsNothing);
    expect(find.byKey(const ValueKey('gateway-refresh')), findsNothing);
  });

  testWidgets('an old checkout action cannot launch after account changes',
      (tester) async {
    var calls = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_launcher,
        (_) async {
      calls++;
      return true;
    });
    final container = await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    final oldAction = tester
        .widget<AppButton>(find.byKey(const ValueKey('gateway-open-checkout')))
        .onPressed!;
    container.read(gatewayTestSessionProvider.notifier).change('account-b');
    oldAction();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.widgetWithText(SelectableText, _checkout), findsNothing);
    expect(
        find.widgetWithText(SelectableText, gatewayWallet().id), findsNothing);
    expect(find.byKey(const ValueKey('gateway-open-checkout')), findsNothing);
  });

  testWidgets('late launch cannot acknowledge a checkout in another session',
      (tester) async {
    final launched = Completer<bool>();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(_launcher, (_) => launched.future);
    final container = await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.tap(find.byKey(const ValueKey('gateway-open-checkout')));
    await tester.pump();
    container.read(gatewayTestSessionProvider.notifier).change('account-b');
    await tester.pumpAndSettle();
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    container.read(gatewayTestSessionProvider.notifier).change('account-a');
    await tester.pumpAndSettle();
    launched.complete(true);
    await tester.pumpAndSettle();
    expect(find.textContaining('foi aberto'), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late clipboard acknowledgement cannot notify another account',
      (tester) async {
    final copied = Completer<void>();
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await copied.future;
      return null;
    });
    final container = await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.tap(find.text('Mercado Pago'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('gateway-copy-checkout')));
    await tester.tap(find.byKey(const ValueKey('gateway-copy-checkout')));
    await tester.pump();
    container.read(gatewayTestSessionProvider.notifier).change('account-b');
    await tester.pumpAndSettle();
    copied.complete();
    await tester.pumpAndSettle();
    expect(AppScreenFeedbackBus.current.value, isNull);
    expect(find.widgetWithText(SelectableText, _checkout), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late catalog response cannot reveal the previous wallet',
      (tester) async {
    final response = Completer<GatewayLinksSnapshot>();
    final container = await pumpGateway(tester, load: () => response.future);
    container.read(gatewayTestSessionProvider.notifier).change('account-b');
    await tester.pumpAndSettle();
    response.complete(gatewaySnapshot({'Mercado Pago': _checkout}));
    await tester.pumpAndSettle();
    expect(find.text('Mercado Pago'), findsNothing);
    expect(find.text('Carteira principal'), findsNothing);
    expect(find.textContaining('A sessão mudou'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a detached catalog action cannot read disposed providers',
      (tester) async {
    await pumpGateway(tester,
        load: () async => gatewaySnapshot({'Mercado Pago': _checkout}));
    final oldAction = tester
        .widget<InkWell>(find
            .ancestor(
                of: find.text('Mercado Pago'), matching: find.byType(InkWell))
            .first)
        .onTap!;
    await tester.pumpWidget(const SizedBox.shrink());
    oldAction();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

final gatewayTestSessionProvider =
    NotifierProvider<GatewayTestSession, String?>(GatewayTestSession.new);

class GatewayTestSession extends Notifier<String?> {
  @override
  String? build() => 'account-a';
  void change(String? scope) => state = scope;
}

class _GatewayRepository implements TransactionRepository {
  final requests = <Completer<Either<Failure, Map<String, String>>>>[];

  @override
  Future<Either<Failure, Map<String, String>>> getOnrampUrls() {
    final request = Completer<Either<Failure, Map<String, String>>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GatewayLinksSnapshot gatewaySnapshot(Map<String, String> urls) =>
    GatewayLinksSnapshot(urls, DateTime(2026, 10, 12, 10, 30));

Wallet gatewayWallet() => Wallet(
    id: 'wallet-full-identifier-1234567890',
    name: 'Carteira principal',
    address: 'bc1qfixture',
    walletMode: 'KEROSENE',
    balance: 0.1,
    derivationPath: "m/84'/0'/0'/0/0",
    type: WalletType.nativeSegwit,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

Future<ProviderContainer> pumpGateway(WidgetTester tester,
    {required Future<GatewayLinksSnapshot> Function() load,
    AppThemeVariant variant = AppThemeVariant.dark,
    String? scope = 'account-a',
    double scale = 1}) async {
  await tester.binding.setSurfaceSize(const Size(320, 740));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(retry: (_, __) => null, overrides: [
    sessionStorageScopeProvider
        .overrideWith((ref) => ref.watch(gatewayTestSessionProvider)),
    receiveGatewayLinksProvider.overrideWith((ref) => load()),
  ]);
  container.read(gatewayTestSessionProvider.notifier).change(scope);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(variant),
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: KeroseneUiScale(child: child!)),
      home: ReceiveGatewayProvidersScreen(
          key: UniqueKey(), wallet: gatewayWallet()),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}
