import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/services/background_network_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundNetworkBridge', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('publish + read routing snapshot', () async {
      await BackgroundNetworkBridge.publishMainIsolateRouting(
        apiBaseUrl: 'http://127.0.0.1:19050',
        torEnabled: true,
        socksPort: 9050,
      );
      final snap = await BackgroundNetworkBridge.readRouting();
      expect(snap.apiBaseUrl, 'http://127.0.0.1:19050');
      expect(snap.torEnabled, isTrue);
      expect(snap.socksPort, 9050);
      // Local relay is not onion — SOCKS optional.
      expect(snap.isOnionApi, isFalse);
    });

    test('alert prefs default and allow financial kinds', () async {
      final prefs = await BackgroundNetworkBridge.readAlertPrefs();
      expect(prefs.transactionAlertsEnabled, isTrue);
      expect(prefs.allowsKind('deposit_detected'), isTrue);
      expect(prefs.allowsKind('security_login_detected'), isTrue);
    });

    test('alert prefs respect disabled transaction flag', () async {
      SharedPreferences.setMockInitialValues({
        'transaction_alerts_enabled': false,
      });
      final prefs = await BackgroundNetworkBridge.readAlertPrefs();
      expect(prefs.allowsKind('deposit_confirmed'), isFalse);
      expect(prefs.allowsKind('security_login_detected'), isTrue);
    });

    test('remember and load seen ids', () async {
      await BackgroundNetworkBridge.rememberSeenIds({'1', '2', '3'});
      final seen = await BackgroundNetworkBridge.loadSeenIds();
      expect(seen, containsAll(['1', '2', '3']));
    });
  });
}
