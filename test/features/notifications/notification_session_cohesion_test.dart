import 'package:flutter/rendering.dart';
import 'package:kerosene/core/utils/snackbar_helper.dart';
import 'package:kerosene/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:kerosene/core/providers/session_invalidation_provider.dart';
import 'package:kerosene/core/providers/tor_providers.dart';
import 'package:kerosene/core/security/kerosene_secure_prefix.dart';
import 'package:kerosene/core/services/balance_websocket_service.dart';
import 'package:kerosene/features/auth/controller/auth_local_provider.dart';
import 'package:kerosene/features/financial_accounts/presentation/providers/balance_websocket_provider.dart';
import 'package:kerosene/features/notifications/presentation/notification_navigation.dart';
import 'package:kerosene/features/movement/providers/transaction_provider.dart';
import 'package:kerosene/features/movement/domain/entities/transaction.dart';
import 'package:kerosene/features/movement/presentation/activity/transaction_detail_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dartz/dartz.dart' show Either, Right, Left;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kerosene/core/errors/failures.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/components/feedback/app_notice.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/domain/entities/user.dart';
import 'package:kerosene/features/notifications/domain/entities/session_notification_item.dart';
import 'package:kerosene/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kerosene/features/notifications/presentation/providers/session_notification_provider.dart';
import 'package:kerosene/features/notifications/presentation/widgets/global_notification_host.dart';
import '../../goldens/golden_harness.dart';

SessionNotificationItem notice(String id, {bool financial = true}) =>
    SessionNotificationItem(
      id: id,
      title: id,
      body: 'Registro público fictício para revisão.',
      timestamp: DateTime.utc(2026, 10, 14),
      kind: financial
          ? SessionNotificationItem.kindPaymentSent
          : SessionNotificationItem.kindSystemInfo,
    );

class _Auth extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(
      User(id: '1', username: 'fixture', createdAt: DateTime.utc(2026)));
  void change(String? id, {String username = 'fixture'}) {
    state = id == null
        ? const AuthInitial()
        : AuthAuthenticated(
            User(id: id, username: username, createdAt: DateTime.utc(2026)));
  }
}

class _Repository extends Mock implements NotificationRepository {
  final pending = <Completer<Either<Failure, List<SessionNotificationItem>>>>[];
  @override
  Future<Either<Failure, List<SessionNotificationItem>>> getNotifications() {
    final result = Completer<Either<Failure, List<SessionNotificationItem>>>();
    pending.add(result);
    return result.future;
  }
}

class _FixtureUrl extends TorApiUrlNotifier {
  @override
  String build() => 'http://fixture.invalid';
}

class _UnavailableCredentials extends Mock implements AuthLocalDataSource {
  @override
  Future<String?> getToken() async => throw StateError('fixture unavailable');
}

class _Probe extends StatefulWidget {
  final VoidCallback created;
  const _Probe(this.created);
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.created();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Tela preservada'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeGoldenHarness);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppScreenFeedbackBus.clear();
  });
  tearDown(AppScreenFeedbackBus.clear);
  ProviderContainer make(_Repository repo) => ProviderContainer(overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        notificationRepositoryProvider.overrideWithValue(repo),
      ]);

  test(
      'a live undated notice remains in the bounded inbox without dropping rows on duplicate updates',
      () {
    final container = make(_Repository());
    addTearDown(container.dispose);
    final feed = container.read(sessionNotificationFeedProvider.notifier);
    for (var index = 0; index < 50; index++) {
      feed.add(notice('record-$index'));
    }
    feed.add(SessionNotificationItem.fromJson({
      'id': 'undated-live',
      'title': 'Public fixture',
      'body': 'Recorded notice'
    }));
    expect(container.read(sessionNotificationFeedProvider), hasLength(50));
    expect(
        container
            .read(sessionNotificationFeedProvider)
            .any((item) => item.id == 'undated-live'),
        isTrue);
    final existing = container
        .read(sessionNotificationFeedProvider)
        .firstWhere((item) => item.id != 'undated-live');
    feed.add(existing.copyWith(body: 'updated record'));
    expect(container.read(sessionNotificationFeedProvider), hasLength(50));
    expect(
        container.read(sessionNotificationFeedProvider),
        contains(predicate<SessionNotificationItem>(
            (item) => item.id == 'undated-live')));
    expect(
        container
            .read(sessionNotificationFeedProvider)
            .firstWhere((item) => item.id == existing.id)
            .body,
        'updated record');
  });

  test(
      'query status preserves the last success and coalesces concurrent refreshes',
      () async {
    final repo = _Repository();
    final container = make(repo);
    addTearDown(container.dispose);
    container.listen(sessionNotificationFeedProvider, (_, __) {});
    final feed = container.read(sessionNotificationFeedProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final first = feed.reloadFromServer();
    expect(feed.reloadFromServer(), same(first));
    expect(repo.pending, hasLength(1));
    expect(container.read(sessionNotificationSyncProvider).loading, isTrue);
    repo.pending.first.complete(Right([notice('1')]));
    expect(await first, isTrue);
    final checkedAt =
        container.read(sessionNotificationSyncProvider).lastSyncedAt;
    expect(checkedAt, isNotNull);
    await Future<void>.delayed(Duration.zero);
    final second = feed.reloadFromServer();
    repo.pending.last
        .complete(const Left(ServerFailure(message: 'fixture unavailable')));
    expect(await second, isFalse);
    final status = container.read(sessionNotificationSyncProvider);
    expect(status.lastSyncedAt, checkedAt);
    expect(status.failed, isTrue);
    expect(status.loading, isFalse);
    expect(container.read(sessionNotificationFeedProvider).single.id, '1');
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(
        DateTime.parse(
                prefs.getString('session_notification_feed_v3-1-last-query')!)
            .toUtc(),
        checkedAt!.toUtc());
  });

  test('late query cannot set freshness or failure on a new account', () async {
    final repo = _Repository();
    final container = make(repo);
    addTearDown(container.dispose);
    container.listen(sessionNotificationFeedProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    final first = container
        .read(sessionNotificationFeedProvider.notifier)
        .reloadFromServer();
    (container.read(authControllerProvider.notifier) as _Auth).change('2');
    container.read(sessionNotificationFeedProvider);
    await Future<void>.delayed(Duration.zero);
    expect(repo.pending, hasLength(2));
    repo.pending.first
        .complete(const Left(ServerFailure(message: 'old query')));
    expect(await first, isFalse);
    final status = container.read(sessionNotificationSyncProvider);
    expect(status.lastSyncedAt, isNull);
    expect(status.failed, isFalse);
    expect(status.loading, isTrue);
  });

  test('server record corrects a cached invented date and stale metadata',
      () async {
    final old = notice('1').copyWith(
        read: true,
        timestamp: DateTime.utc(2030),
        metadata: {'address': 'stale-address'});
    SharedPreferences.setMockInitialValues({
      'session_notification_feed_v3-1': [jsonEncode(old.toJson())],
      'session_notification_feed_v3-1-last-query': '2020-01-02T03:04:05Z',
    });
    final repo = _Repository();
    final container = make(repo);
    addTearDown(container.dispose);
    container.listen(sessionNotificationFeedProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(sessionNotificationSyncProvider).lastSyncedAt?.toUtc(),
        DateTime.utc(2020, 1, 2, 3, 4, 5));
    final query = container
        .read(sessionNotificationFeedProvider.notifier)
        .reloadFromServer();
    repo.pending.first.complete(Right([
      SessionNotificationItem.fromJson({
        'id': '1',
        'kind': SessionNotificationItem.kindPaymentBroadcast,
        'title': 'Recorded operation',
        'body': 'Recorded amount',
        'metadata': {'amountSats': '123'},
      })
    ]));
    expect(await query, isTrue);
    final item = container.read(sessionNotificationFeedProvider).single;
    expect(item.timestamp, isNull);
    expect(item.read, isTrue);
    expect(item.kind, SessionNotificationItem.kindPaymentBroadcast);
    expect(item.body, 'Recorded amount');
    expect(item.metadata, {'amountSats': '123'});
  });

  test(
      'a live event survives equal-date cache hydration and undated records stay undated',
      () async {
    final cached = notice('same').copyWith(body: 'old cached text');
    SharedPreferences.setMockInitialValues({
      'session_notification_feed_v3-1': [jsonEncode(cached.toJson())]
    });
    final container = make(_Repository());
    addTearDown(container.dispose);
    container.listen(sessionNotificationFeedProvider, (_, __) {});
    final feed = container.read(sessionNotificationFeedProvider.notifier);
    feed.add(notice('same').copyWith(body: 'live recorded text'));
    feed.add(SessionNotificationItem.fromJson({
      'id': 'undated',
      'title': 'Date unavailable',
      'body': 'Public fixture'
    }));
    await Future<void>.delayed(Duration.zero);
    final items = container.read(sessionNotificationFeedProvider);
    expect(items.first.body, 'live recorded text');
    expect(items.last.timestamp, isNull);
  });

  test(
      'banner queue and sidebar reset; an old close cannot dismiss a new notice',
      () {
    final container = make(_Repository());
    addTearDown(container.dispose);
    final banner = container.read(notificationBannerProvider.notifier);
    final first = notice('old');
    banner.show(first);
    container.read(notificationSidebarProvider.notifier).open();
    (container.read(authControllerProvider.notifier) as _Auth).change('2');
    expect(container.read(notificationBannerProvider), isNull);
    expect(container.read(notificationSidebarProvider), isFalse);
    final fresh = notice('new');
    banner.show(fresh);
    banner.dismiss(expected: first);
    expect(container.read(notificationBannerProvider), same(fresh));
    (container.read(authControllerProvider.notifier) as _Auth).change(null);
    expect(container.read(notificationBannerProvider), isNull);
    banner.show(first);
    container.read(notificationSidebarProvider.notifier).open();
    expect(container.read(notificationBannerProvider), isNull);
    expect(container.read(notificationSidebarProvider), isFalse);
  });

  test(
      'same account metadata does not erase events and late remote responses are ignored',
      () async {
    final repo = _Repository();
    final container = make(repo);
    addTearDown(container.dispose);
    container.listen(sessionNotificationFeedProvider, (_, __) {});
    final feed = container.read(sessionNotificationFeedProvider.notifier);
    feed.add(notice('live'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.pending, hasLength(1));
    (container.read(authControllerProvider.notifier) as _Auth)
        .change('1', username: 'renamed');
    expect(
        container.read(sessionNotificationFeedProvider).map((item) => item.id),
        contains('live'));
    (container.read(authControllerProvider.notifier) as _Auth).change(null);
    expect(container.read(sessionNotificationFeedProvider), isEmpty);
    (container.read(authControllerProvider.notifier) as _Auth).change('1');
    expect(container.read(sessionNotificationFeedProvider), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(repo.pending, hasLength(2));
    repo.pending.first.complete(Right([notice('stale-session')]));
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(sessionNotificationFeedProvider).map((item) => item.id),
        isNot(contains('stale-session')));
    repo.pending.last.complete(Right([notice('fresh-session')]));
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(sessionNotificationFeedProvider).map((item) => item.id),
        contains('fresh-session'));
  });

  test('cache hydration merges with an event received while storage loads',
      () async {
    SharedPreferences.setMockInitialValues({
      'session_notification_feed_v3-1': [jsonEncode(notice('cached').toJson())]
    });
    final repo = _Repository();
    final container = make(repo);
    addTearDown(container.dispose);
    container.listen(sessionNotificationFeedProvider, (_, __) {});
    container
        .read(sessionNotificationFeedProvider.notifier)
        .add(notice('live'));
    await Future<void>.delayed(Duration.zero);
    expect(
        container.read(sessionNotificationFeedProvider).map((item) => item.id),
        containsAll(['cached', 'live']));
  });

  testWidgets(
      'account change removes private overlays without restarting the page',
      (tester) async {
    final container = make(_Repository());
    addTearDown(container.dispose);
    var starts = 0;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => GlobalNotificationHost(child: child!),
            home: _Probe(() => starts++))));
    container
        .read(notificationBannerProvider.notifier)
        .show(notice('Aviso da conta anterior', financial: false));
    AppScreenFeedbackBus.show(
        type: AppNoticeType.info,
        title: 'Dados anteriores',
        message: 'Mensagem anterior',
        duration: Duration.zero);
    await tester.pumpAndSettle();
    expect(find.text('Aviso da conta anterior'), findsOneWidget);
    (container.read(authControllerProvider.notifier) as _Auth).change('2');
    await tester.pumpAndSettle();
    expect(find.text('Aviso da conta anterior'), findsNothing);
    expect(find.text('Mensagem anterior'), findsNothing);
    expect(starts, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reduced motion removes transition delay for banner and feedback',
      (tester) async {
    final container = make(_Repository());
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: GlobalNotificationHost(child: child!)),
            home: const Scaffold())));
    container
        .read(notificationBannerProvider.notifier)
        .show(notice('Movimento reduzido'));
    await tester.pump();
    expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero);
    expect(find.byType(AnimatedSize), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('late notification details cannot open after logout and login',
      (tester) async {
    final pending = Completer<List<Transaction>>();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_Auth.new),
      transactionHistoryProvider.overrideWith((ref) => pending.future),
    ]);
    addTearDown(container.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: Text('Base')))));
    final item = SessionNotificationItem(
        id: 'event',
        title: 'Evento público',
        body: '',
        timestamp: DateTime.utc(2026),
        kind: SessionNotificationItem.kindPaymentSent,
        entityId: 'operation');
    final opening = NotificationNavigation.openWithNavigator(
        item, navigatorKey.currentState!);
    final auth = container.read(authControllerProvider.notifier) as _Auth;
    auth.change(null);
    container.read(sessionStorageScopeProvider);
    auth.change('1');
    container.read(sessionStorageScopeProvider);
    pending.complete([
      Transaction(
          id: 'operation',
          fromAddress: 'public-a',
          toAddress: 'public-b',
          amountSatoshis: 1,
          feeSatoshis: 0,
          status: TransactionStatus.confirmed,
          type: TransactionType.send,
          confirmations: 6,
          timestamp: DateTime.utc(2026))
    ]);
    await opening;
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailScreen), findsNothing);
    expect(find.text('Base'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'market review preserves recorded precision and closes on account change',
      (tester) async {
    final container = make(_Repository());
    addTearDown(container.dispose);
    final key = GlobalKey<NavigatorState>();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            navigatorKey: key,
            theme: AppTheme.darkTheme,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: Text('Base')))));
    final item = SessionNotificationItem(
        id: 'market-public',
        title: 'Cotação registrada',
        body: 'Dados fictícios.',
        timestamp: DateTime.utc(2020),
        kind: SessionNotificationItem.kindMarketAlert,
        deeplink: '/market',
        metadata: const {
          'priceUsd': '123456.789123',
          'dailyChangePercent': '-2.123456',
          'source': 'fixture'
        });
    final opening =
        NotificationNavigation.openWithNavigator(item, key.currentState!);
    await tester.pumpAndSettle();
    expect(find.text('123456.789123'), findsOneWidget);
    expect(find.text('-2.123456'), findsOneWidget);
    expect(find.text('Preço (USD)'), findsOneWidget);
    expect(find.text('Ver mercado'), findsOneWidget);
    expect(tester.takeException(), isNull);
    (container.read(authControllerProvider.notifier) as _Auth).change('2');
    container.read(sessionStorageScopeProvider);
    await tester.pumpAndSettle();
    await opening;
    expect(find.text('123456.789123'), findsNothing);
    expect(find.text('Base'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final rotateCredential in [false, true]) {
    test(
        'old socket cannot publish or invalidate a newer session: $rotateCredential',
        () async {
      SharedPreferences.setMockInitialValues({
        'device_hash_key_${keroseneProfileTag()}': List.filled(64, 'a').join()
      });
      final container = ProviderContainer(overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        authLocalDataSourceProvider
            .overrideWithValue(_UnavailableCredentials()),
        torApiUrlProvider.overrideWith(_FixtureUrl.new),
        financialPollAllowedProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);
      container.listen(balanceWebSocketServiceProvider, (_, __) {});
      final service =
          await container.read(balanceWebSocketServiceProvider.future);
      expect(service, isNotNull);
      if (rotateCredential) {
        container.read(sessionCredentialVersionProvider.notifier).bump();
      } else {
        (container.read(authControllerProvider.notifier) as _Auth).change('2');
      }
      final fresh = notice('current-account');
      container.read(notificationBannerProvider.notifier).show(fresh);
      service!.onNotification!(RealtimeNotificationEvent(
          id: 'stale-socket',
          kind: SessionNotificationItem.kindSystemInfo,
          severity: SessionNotificationItem.severityInfo,
          title: 'Mensagem anterior',
          body: '',
          timestamp: DateTime.utc(2026)));
      service.onSessionInvalidated!();
      expect(container.read(notificationBannerProvider), same(fresh));
      expect(container.read(sessionInvalidationProvider), 0);
    });
  }
  testWidgets('banner above Navigator can open the notification center',
      (tester) async {
    final repo = _Repository();
    final container = make(repo);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            navigatorKey: SnackbarHelper.navigatorKey,
            theme: AppTheme.darkTheme,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (_, child) => GlobalNotificationHost(child: child!),
            home: const Scaffold(body: Text('Base')))));
    container
        .read(notificationBannerProvider.notifier)
        .show(notice('Abrir central', financial: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir central'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NotificationCenterScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final request in List.of(repo.pending)) {
      if (!request.isCompleted) request.complete(const Right([]));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('sidebar renders the complete public reference without ellipsis',
      (tester) async {
    final container = make(_Repository());
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (_, child) => GlobalNotificationHost(child: child!),
            home: const Scaffold())));
    final body =
        'Registro público fictício para revisão visual: ${List.filled(8, 'abcdef0123456789').join()}';
    container.read(sessionNotificationFeedProvider.notifier).add(
        SessionNotificationItem(
            id: 'long-public',
            title: 'Registro de teste',
            body: body,
            timestamp: DateTime.utc(2020),
            kind: SessionNotificationItem.kindSystemInfo));
    container.read(notificationSidebarProvider.notifier).open();
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(find.text(body));
    final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: body.length - 16, extentOffset: body.length));
    expect(boxes, isNotEmpty);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
