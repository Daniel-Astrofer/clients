import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kerosene/features/movement/screens/send_destination_models.dart';
import 'package:kerosene/features/movement/domain/entities/fee_estimate.dart';
import 'package:kerosene/features/financial_accounts/domain/entities/wallet.dart';
import 'package:kerosene/features/movement/domain/payment_intent_resolver.dart';

class SendMoneyFlowState {
  final int currentStep;
  final String lockedRecipientAddress;
  final String? lockedRecipientLabel;
  final double lockedAmountBtc;
  final Wallet? selectedWallet;
  final ResolvedPaymentIntent? liveResolvedIntent;
  final PaymentRail? userSelectedRail;
  final SendDestinationAnalysis? destinationAnalysis;
  final NetworkFeeTier selectedFeeTier;

  const SendMoneyFlowState({
    this.currentStep = 0,
    this.lockedRecipientAddress = '',
    this.lockedRecipientLabel,
    this.lockedAmountBtc = 0.0,
    this.selectedWallet,
    this.liveResolvedIntent,
    this.userSelectedRail,
    this.destinationAnalysis,
    this.selectedFeeTier = NetworkFeeTier.standard,
  });

  SendMoneyFlowState copyWith({
    int? currentStep,
    String? lockedRecipientAddress,
    String? lockedRecipientLabel,
    double? lockedAmountBtc,
    Wallet? selectedWallet,
    ResolvedPaymentIntent? liveResolvedIntent,
    PaymentRail? userSelectedRail,
    SendDestinationAnalysis? destinationAnalysis,
    NetworkFeeTier? selectedFeeTier,
  }) {
    return SendMoneyFlowState(
      currentStep: currentStep ?? this.currentStep,
      lockedRecipientAddress: lockedRecipientAddress ?? this.lockedRecipientAddress,
      lockedRecipientLabel: lockedRecipientLabel ?? this.lockedRecipientLabel,
      lockedAmountBtc: lockedAmountBtc ?? this.lockedAmountBtc,
      selectedWallet: selectedWallet ?? this.selectedWallet,
      liveResolvedIntent: liveResolvedIntent ?? this.liveResolvedIntent,
      userSelectedRail: userSelectedRail ?? this.userSelectedRail,
      destinationAnalysis: destinationAnalysis ?? this.destinationAnalysis,
      selectedFeeTier: selectedFeeTier ?? this.selectedFeeTier,
    );
  }
}

class SendMoneyFlowNotifier extends AsyncNotifier<SendMoneyFlowState> {
  @override
  FutureOr<SendMoneyFlowState> build() async {
    return const SendMoneyFlowState();
  }

  void setStep(int step) {
    state = AsyncValue.data(state.value!.copyWith(currentStep: step));
  }

  void updateDestination(SendDestinationAnalysis destination, {
    String? lockedAddress,
    String? lockedLabel,
    double? lockedAmount,
    ResolvedPaymentIntent? liveIntent,
    PaymentRail? userRail,
  }) {
    state = AsyncValue.data(state.value!.copyWith(
      destinationAnalysis: destination,
      lockedRecipientAddress: lockedAddress ?? state.value!.lockedRecipientAddress,
      lockedRecipientLabel: lockedLabel ?? state.value!.lockedRecipientLabel,
      lockedAmountBtc: lockedAmount ?? state.value!.lockedAmountBtc,
      liveResolvedIntent: liveIntent ?? state.value!.liveResolvedIntent,
      userSelectedRail: userRail ?? state.value!.userSelectedRail,
    ));
  }

  void selectWallet(Wallet wallet) {
    state = AsyncValue.data(state.value!.copyWith(selectedWallet: wallet));
  }
  
  void setFeeTier(NetworkFeeTier tier) {
    state = AsyncValue.data(state.value!.copyWith(selectedFeeTier: tier));
  }
}

final sendMoneyFlowProvider = AsyncNotifierProvider<SendMoneyFlowNotifier, SendMoneyFlowState>(() {
  return SendMoneyFlowNotifier();
});
