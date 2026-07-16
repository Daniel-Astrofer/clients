# Canivete suíço de pagamentos (meta ≥ 9,5)

Documento de contrato do programa de unificação do fluxo de envio no frontend.
Plano completo: sessão plan `PAYMENT_SWISS_ARMY` / meta scorecard.

## Feature flag

| Flag | Default | Efeito |
|------|---------|--------|
| `unified_send_v2` | `false` (local prefs) ou `KERO_UNIFIED_SEND_V2=true` | Liga motor unificado quando PR6+ estiverem prontos |

Leitura no app: `unifiedSendV2EnabledProvider`.

## Scorecard de liberação

Fórmula:

```
score =
  0.18*parsing + 0.18*rails + 0.16*reactive +
  0.18*security + 0.15*cold + 0.15*io_channels
```

| Dimensão | Baseline | Meta | Status |
|----------|---------:|-----:|--------|
| Intent parsing | 7,5 | 9,5 | PR0+PR1 landed (parser canônico + tests) |
| Multi-rail abstraction | 6,0 | 9,5 | PR3+PR6: resolver + cold same wizard |
| Reactive UX | 7,0 | 9,5 | PR3+PR4+PR7: live resolve, fees, offline, haptics |
| Security | 7,5 | 9,5 | PR5: gate cold + network/first-send/quote guards |
| Cold wallet | 5,0 | 9,5 | PR6: cold no wizard unificado |
| Links / QR / NFC / username | 7,0 | 9,5 | PR2: capture sheet QR/NFC/paste + NFC round-trip |
| **Geral** | ~6,5 | **≥ 9,5** | engineering complete 0–7; PR8 QA sign-off |

### Checks por dimensão (binários)

**Parsing**
- [x] Parser canônico único (`PaymentIntentParser`)
- [x] Home paste e send: mesma saída (fixture compartilhada)
- [x] ≥ 40 unit tests + fuzz sem crash
- [x] Username inválido ≠ payment link falso

**Rails**
- [x] Capabilities (`preferredRail`, lightning, onchain) usadas (`PaymentIntentResolver`)
- [x] Seletor one-tap quando 2+ rails (`_RailPicker`)
- [x] Cold nunca tenta ledger send (blockers no resolver)
- [x] Cold no mesmo wizard unificado (PR6)

**Reactive**
- [x] Live resolve username (debounce 350ms)
- [x] Fee quote expiry hard-block + auto-refresh (PR4)
- [x] On-chain fee tiers Rápido/Normal/Econômico (PR4)
- [x] LN sem fee inventada (`unknownUntilPay`) (PR4)
- [x] Offline banner + bloqueia submit/scan (PR7)
- [x] Haptics em detect type / fee tier / sucesso (PR7)
- [x] Notificação pós-envio (AppNotice) (PR7)
- [x] Semantics no botão de captura de destino (PR7)

**Security**
- [x] `TransactionAuthGate` em cold + custodial (PR5)
- [x] Network mismatch block (resolver + confirm + cold)
- [x] Self-pay / quote stale block
- [x] First-time on-chain address confirmation
- [x] `allowDeviceAuthUnavailable: false` no confirm (não skip fatores)

**Cold**
- [x] Auth unificado (`TransactionAuthGate` + forceTotp)
- [x] Copy sem PSBT no happy path
- [x] Mesmo wizard que custodial (PR6 — sem fork ColdWalletSendScreen)
- [x] Seed ausente bloqueia com CTA claro
- [x] Fee avançada escondida (expand) no legado cold screen

**IO channels**
- [x] NFC pay no produto (DestinationCaptureSheet + NfcScanDialog)
- [x] Round-trip receive encode → parse (nfc_payment_roundtrip_test)
- [x] QR / NFC / colar no mesmo sheet de captura
- [x] Busca local de contatos recentes (≥3 chars)

## Matriz de rails

| Input | Kind | Source típica | Rail | Executor |
|-------|------|---------------|------|----------|
| `@user` / username / uuid | internal | INTERNAL / CUSTODIAL | internal (preferred) | LedgerSend |
| `kerosene://…/pay/id` | paymentLink | ledger spendable | paymentLink | LinkPay |
| `bc1…` / BIP-21 | onchain | CUSTODIAL / WATCH_ONLY | onchain / coldOnchain | Withdraw / ColdPsbt |
| `lnbc…` / LNURL / email-like | lightning | CUSTODIAL | lightning | Withdraw LN |

## Domain canônico

- `frontend/lib/features/movement/domain/payment_intent.dart`
- `frontend/lib/features/movement/domain/payment_intent_parser.dart`

Wrappers legados (`analyzeSendDestination`, `PaymentPayloadDraft`) devem delegar ao parser.

## Cold create handoff (fora do send)

Criação/import de cold é outro fluxo. O send unificado espera:

| Campo | Uso |
|-------|-----|
| `kind: WATCH_ONLY` + xpub/descriptor | Dashboard + PSBT |
| Seed em `ColdWalletKeyVault` com **mesmo** `walletId` do KFE | Assinatura local |
| Endereço receive emitido | Receive / destino |
| `observed_sats` (chain) | Saldo UI |

Pós-create: `SendMoneyScreen(walletId: id)` ou receive hub — **não** reabrir tela legada de PSBT.

### Implementado (Phase 1–3)

- `RegisterColdWalletUseCase` — derive (path de rede) → KFE import → vault sob id KFE
- Path BIP84: `appColdWalletDerivationPath` (`m/84'/0|1'/0'` via `expectedBitcoinNetwork`)
- Hub (`WalletSetupHubScreen`): criar no aparelho + importar seed; multisig / xpub-only desabilitados
- Wizard create + import hub compartilham o use case
- `ColdWalletSuccessScreen` → `ColdWalletFlowOutcome` · hub fecha e **Enviar** faz `pushReplacement` em `SendMoneyScreen`
- Secure seed: `SecureScreenGuard` (Android `FLAG_SECURE`) + auto-hide no background (`SecureSeedVisibility`)
- Testes: `test/features/financial_accounts/domain/register_cold_wallet_use_case_test.dart`

## Receiving capabilities (Fase A)

KFE `receivingCapabilities` inclui:

- `onchainReceiveAddress` / `onchainWalletId` — dual-rail @user → on-chain
- `preferredRail` apenas entre rails disponíveis (`INTERNAL` > `LIGHTNING` > `ONCHAIN`)

O FE passa `onchainReceiveAddress` ao `PaymentIntentResolver` como `destOnchainAddress`.

## PR order

0 Fundação → 1 Parser → 2 NFC → 3 Resolver → 4 Fees → 5 Security → 6 Unified engine → 7 Polish → **8 QA gate (smoke manual)**

## Status engineering (2026-07-15)

PRs **0–7 implementados no código**. PR8 = smoke em device + preencher matriz e2e abaixo.

| # | Cenário | Pass |
|---|---------|------|
| 1 | @user internal | |
| 2 | payment link amount locked | |
| 3 | BIP-21 amount lock | |
| 4 | tb1 custodial + fee tier | |
| 5 | LN invoice (se LN up) | |
| 6 | NFC receive→pay | |
| 7 | QR scan pay | |
| 8 | Deep link pay | |
| 9 | Cold send on-chain no wizard | |
| 10 | Cold seed missing CTA | |
| 11 | Network mismatch block | |
| 12 | Quote expired block | |
| 13 | Self-pay block | |
| 14 | Auth cancel mid-flow | unit: `isAuthUserCancellation` + payment-link passkey cancel (silent); device QA remaining |
| 15 | Dual-rail switch | |
| 16 | Offline banner + blocked send | |

Unit tests de domínio: `flutter test test/features/movement/domain/`

Smoke automatizado (sem device):  
`flutter test test/features/movement/domain/payment_swiss_army_smoke_test.dart`

Entrada cold na tela de contas Bitcoin também abre `SendMoneyScreen` (wizard unificado).
