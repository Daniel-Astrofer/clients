import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';
import 'package:kerosene/app/security/payment_security_guards.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_screen_review.dart';

void main() {
  test('review and first-send acknowledgment retain the complete destination',
      () {
    const address = 'bc1qabcdefghijklmnopqrstuvwxyz0123456789abcdefgh';
    expect(sendShortHash(address), address);
    expect(compactInternalValue(address), address);
    expect(compactSendReceiptValue(address), address);
    expect(firstSendAddressPreview(address), address);
  });
  const onchain = SendDestinationAnalysis(
    type: SendDestinationType.onChain,
    normalizedValue: 'bcrt1qdestination',
  );
  const lightning = SendDestinationAnalysis(
    type: SendDestinationType.lightning,
    normalizedValue: 'lnbcrt1invoice',
  );

  test('uses the server settlement estimate for on-chain review', () {
    expect(
      estimatedSendTime(onchain, estimatedSeconds: 1800),
      '~30 min',
    );
    expect(
      estimatedSendTime(onchain, estimatedSeconds: 4500),
      '~1 h 15 min',
    );
  });

  test('keeps a deterministic fallback when the quote has no estimate', () {
    expect(estimatedSendTime(onchain), '~10 min');
    expect(
      estimatedSendTime(lightning, estimatedSeconds: 1800),
      'Segundos',
    );
  });
}
