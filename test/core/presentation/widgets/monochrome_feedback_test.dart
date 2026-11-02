import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/core/providers/appearance_provider.dart';
import 'package:kerosene/design_system/components/feedback/app_notification_surface.dart';
import 'package:kerosene/design_system/components/financial/send_flow_theme.dart';
import 'package:kerosene/design_system/foundation/theme/app_theme.dart';
import 'package:kerosene/design_system/foundation/theme/kerosene_brand_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kerosene/core/l10n/app_localizations.dart';
import 'package:kerosene/design_system/foundation/assets/icons/kerosene_icons.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';
import 'package:kerosene/features/auth/controller/auth_controller.dart';

void main() {
  for (final variant in AppThemeVariant.values) {
    testWidgets('receipt mark contrasts with paper in $variant',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageScopeProvider.overrideWithValue('user_receipt_fixture'),
        ],
        child: MaterialApp(
          theme: AppTheme.themeFor(variant),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SendPaymentReceiptScreen<bool>(
            result: false,
            data: SendPaymentReceiptData(
              title: 'Envio registrado',
              amountLabel: '1 BTC',
              occurredAt: null,
              confirmed: false,
              rows: [],
              shareText: '',
            ),
          ),
        ),
      ));
      await tester.pump();
      final mark = tester.widget<Icon>(find.byIcon(KeroseneIcons.pending));
      expect(mark.color!.computeLuminance(), lessThan(0.05));
      expect(tester.widget<Text>(find.text('1 BTC')).style!.fontFamily,
          contains('PlusJakartaSans'));
      expect(tester.takeException(), isNull);
    });
    testWidgets('states retain distinct icons and monochrome ink: $variant',
        (tester) async {
      final theme = AppTheme.themeFor(variant);
      final ink = theme.extension<KeroseneBrandTheme>()!.textPrimary;
      final icons = <IconData>{};
      for (final tone in AppNotificationTone.values) {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: AppNotificationSurface(
              title: tone.name,
              message: 'Estado da operação',
              tone: tone,
            ),
          ),
        ));
        final icon = AppNotificationStyle.iconFor(tone);
        icons.add(icon);
        expect(tester.widget<Icon>(find.byIcon(icon)).color, ink);
        expect(find.text(tone.name), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(icons.length, AppNotificationTone.values.length);
      final flow = SendFlowTheme.forVariant(theme.brightness);
      expect(flow.feedbackError, ink);
      expect(flow.feedbackSuccess, ink);
      expect(flow.feedbackWarning, ink);
    });
  }
}
