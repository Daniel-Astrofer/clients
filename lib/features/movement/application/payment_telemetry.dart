import 'package:flutter/foundation.dart';
import 'package:kerosene/features/movement/kernel/intent/payment_intent.dart';

/// Minimal payment telemetry — never log full addresses or seeds.
void logPaymentEvent({
  required String event,
  PaymentDestinationKind? kind,
  PaymentRail? rail,
  SourceCustody? source,
  bool? success,
  String? errorCode,
}) {
  if (!kDebugMode) {
    // Hook for production analytics later; keep silent for now.
    return;
  }
  final parts = <String>[
    event,
    if (kind != null) 'kind=${kind.name}',
    if (rail != null) 'rail=${rail.name}',
    if (source != null) 'source=${source.name}',
    if (success != null) 'success=$success',
    if (errorCode != null && errorCode.isNotEmpty) 'error=$errorCode',
  ];
  debugPrint('[payment] ${parts.join(' ')}');
}
