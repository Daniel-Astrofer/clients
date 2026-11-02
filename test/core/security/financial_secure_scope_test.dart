import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/privacy_preferences_provider.dart';
import 'package:kerosene/core/security/financial_secure_scope.dart';

class _Privacy extends PrivacyPreferencesNotifier {
  @override
  PrivacyPreferencesState build() =>
      const PrivacyPreferencesState(blockFinancialScreenshots: true);
  void loading() => state = state.copyWith(loading: true);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.kerosene.app/secure_screen');
  for (final disposeWhilePending in [false, true]) {
    testWidgets(
        'financial protection has one guard across metadata updates/disposal: $disposeWhilePending',
        (tester) async {
      final platform = <bool>[];
      final pending = Completer<void>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        final enabled = call.arguments['enabled'] as bool;
        platform.add(enabled);
        if (enabled) await pending.future;
        return null;
      });
      addTearDown(() => binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final container = ProviderContainer(
          overrides: [privacyPreferencesProvider.overrideWith(_Privacy.new)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
              home: FinancialSecureScope(child: SizedBox()))));
      await tester.pump();
      expect(platform, [true]);
      (container.read(privacyPreferencesProvider.notifier) as _Privacy)
          .loading();
      await tester.pump();
      if (disposeWhilePending) {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      pending.complete();
      await tester.pump();
      if (!disposeWhilePending) {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
      expect(platform, [true, false]);
      expect(tester.takeException(), isNull);
    });
  }
}
