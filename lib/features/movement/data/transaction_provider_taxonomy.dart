/// Stable provider taxonomy aligned with KFE [KfeResponseMapper.normalizeProvider].
enum TransactionProviderKind {
  coldObserve,
  coldSpend,
  paymentLink,
  lightning,
  custodialOnchain,
  internalLedger,
  unknown,
}

TransactionProviderKind classifyProvider(String? provider) {
  final p = (provider ?? '').trim().toUpperCase();
  if (p.isEmpty) return TransactionProviderKind.unknown;
  if (p == 'COLD_OBSERVE' ||
      p.contains('COLD_OBSERVER') ||
      p.contains('WATCH_ONLY')) {
    return TransactionProviderKind.coldObserve;
  }
  if (p == 'COLD_SPEND' ||
      p.contains('COLD_EXTERNAL') ||
      p.contains('COLD_PSBT') ||
      p.contains('COLD_SPEND')) {
    return TransactionProviderKind.coldSpend;
  }
  if (p == 'PAYMENT_LINK' || p.contains('PAYLINK')) {
    return TransactionProviderKind.paymentLink;
  }
  if (p == 'LIGHTNING' || p.contains('LND') || p.contains('BOLT')) {
    return TransactionProviderKind.lightning;
  }
  if (p == 'CUSTODIAL_ONCHAIN' ||
      p.contains('BITCOIN') ||
      p.contains('ONCHAIN') ||
      p.contains('CUSTODIAL')) {
    return TransactionProviderKind.custodialOnchain;
  }
  if (p == 'INTERNAL_LEDGER' ||
      p.contains('INTERNAL') ||
      p.contains('LEDGER')) {
    return TransactionProviderKind.internalLedger;
  }
  return TransactionProviderKind.unknown;
}

String providerKindLabel(TransactionProviderKind kind) {
  return switch (kind) {
    TransactionProviderKind.coldObserve => 'Cold (observação)',
    TransactionProviderKind.coldSpend => 'Cold (gasto)',
    TransactionProviderKind.paymentLink => 'Link de pagamento',
    TransactionProviderKind.lightning => 'Lightning',
    TransactionProviderKind.custodialOnchain => 'On-chain (plataforma)',
    TransactionProviderKind.internalLedger => 'Ledger interno',
    TransactionProviderKind.unknown => 'Provedor',
  };
}
