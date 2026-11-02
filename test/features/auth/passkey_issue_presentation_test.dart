import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';
import 'package:kerosene/features/auth/presentation/screens/passkey_verification_components.dart';
import 'package:kerosene/features/auth/presentation/screens/passkey_verification_screen.dart';
import 'package:kerosene/storybook/storybook_mocks.dart';

import '../../goldens/golden_harness.dart';

class _UnavailablePasskeyController extends MockAuthController {
  _UnavailablePasskeyController(this.error)
      : super(initialOverride: const AuthUnauthenticated());
  final AuthError error;
  int calls = 0;

  @override
  Future<void> loginWithPasskey(String username,
      {int remainingChallengeRenewals = 2}) async {
    calls++;
    state = error;
  }
}

void main() {
  setUpAll(initializeGoldenHarness);

  for (final theme in AppThemeVariant.values) {
    testWidgets('service outage stays truthful and retryable in $theme',
        (tester) async {
      for (final error in [
        AuthError('private transport diagnostic', statusCode: 503),
        AuthError('private transport diagnostic',
            statusCode: 400, errorCode: 'ERR_KFE_RAIL_PROVIDER_UNAVAILABLE'),
        AuthError('private transport diagnostic',
            statusCode: 503, errorCode: 'ERR_VAULT_NOT_READY'),
      ]) {
        final controller = _UnavailablePasskeyController(error);
        await pumpFullScreenGolden(
          tester,
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(() => controller),
            ],
            child: Theme(
              data: AppTheme.themeFor(theme),
              child: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(1.5),
                  disableAnimations: true,
                ),
                child: PasskeyVerificationScreen(
                  username: 'public-fixture',
                  fallbackPreAuthToken: 'public-fixture-token',
                ),
              ),
            ),
          ),
          size: const Size(320, 640),
        );
        expect(find.text('Entrada indisponível'), findsOneWidget);
        expect(find.textContaining('um serviço da Kerosene'), findsOneWidget);
        expect(find.textContaining('private transport'), findsNothing);
        expect(find.text('Falha na Autenticação'), findsNothing);
        expect(find.text('USAR TOTP'), findsNothing);
        final issue =
            tester.widget<PasskeyIssueView>(find.byType(PasskeyIssueView));
        expect(issue.canUseTotp, isFalse);
        expect(issue.canRetry, isTrue);
        final glyph = tester.widget<Icon>(find
            .descendant(
                of: find.byType(ErrorGlyph),
                matching: find.byWidgetPredicate((widget) => widget is Icon))
            .first);
        final color = glyph.color!;
        expect(
            color,
            KeroseneBrandTheme.of(tester.element(find.byType(ErrorGlyph)))
                .textPrimary);
        if (controller.calls == 1 && error.errorCode == null) {
          await expectLater(
              find.byType(PasskeyVerificationScreen),
              matchesGoldenFile(
                  '../../goldens/goldens/passkey_service_unavailable_${theme.name}.png'));
        }
        await tester.ensureVisible(find.text('TENTAR NOVAMENTE'));
        await tester.tap(find.text('TENTAR NOVAMENTE'));
        await tester.pump();
        expect(controller.calls, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
