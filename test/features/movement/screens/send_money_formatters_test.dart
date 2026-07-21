import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/presentation/send/send_destination_models.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_formatters.dart';

void main() {
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
