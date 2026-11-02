import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerosene/features/movement/presentation/send/send_money_flow_notifier.dart';

void main() {
  test(
      'a new journey clears old recipient, locked amount, status and busy state',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final flow = container.read(sendMoneyFlowProvider.notifier);
    flow.updateDestination(null,
        lockedAddress: 'old-recipient',
        lockedLabel: 'Old recipient',
        lockedAmount: 0.1);
    flow.setStep(2);
    flow.setBusy(true);
    flow.setError('old-failure');
    flow.startJourney();
    final state = container.read(sendMoneyFlowProvider).requireValue;
    expect(state.currentStep, 0);
    expect(state.lockedRecipientAddress, '');
    expect(state.lockedRecipientLabel, isNull);
    expect(state.lockedAmountBtc, 0);
    expect(state.selectedWallet, isNull);
    expect(state.errorMessage, isNull);
    expect(state.isBusy, isFalse);
  });
}
