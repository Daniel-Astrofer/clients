# Flow: Receive Money

> Status: Draft | Applies-to: mobile · web
> Anchors: `lib/features/movement/presentation/receive/receive_amount_entry_screen.dart`
> Last revised: 2026-07-31

## User objective chain

1. **Initiate:** "I want to receive money"
2. **Amount:** "How much should they send?" (optional, can be open)
3. **Method:** "How should they pay me?" (QR, link, NFC, invoice)
4. **Share:** "Send them the payment request"
5. **Wait:** "Did they pay?"
6. **Confirm:** "I received it"

Success metric per step:
1. User reaches receive entry point from Home
2. Amount set (or intentionally left open)
3. Method selected that works for both parties
4. Payment request shared successfully
5. Payment detected
6. Confirmation shown

---

## Screen sequence

```
Home
  │
  └─→ Receive Entry
        Entry: user taps "Receive"
        Exit: amount entered (or skipped)
        Dominant action: amount keyboard input
        Secondary: switch BTC/fiat, leave open, choose wallet
        Motion: push right (136ms easeOutQuart)
        │
        ├─→ [Method Selection] (inline or sub-screen)
        │     Methods: QR code, payment link, Lightning invoice, on-chain address, NFC
        │     Motion: inline expand (260ms easeOutCubic)
        │
        └─→ Share / Display
              Entry: method selected, amount set
              Exit: user shares or payment detected
              Dominant visual: QR code or link/share button
              Secondary: copy, share sheet, NFC ready indicator
              Motion: QR/link renders (no entry animation)
              │
              ├─→ Payment Detected (push notification or WS event)
              │     Dominant action: none (system event)
              │     Motion: status transition (ceremonial)
              │
              └─→ Confirmation
                    Dominant action: "Ver detalhes" or "Fechar"
                    Motion: ceremonial confirmation → summary
```

---

## State matrix

| State | Amount Entry | Share/Display | Confirmation |
|-------|-------------|---------------|-------------|
| Loading | — | Generating invoice/QR | — |
| Empty | No amount entered | — | — |
| Partial | Amount entered, no method | Method not chosen | — |
| Error | — | Invoice generation failed | — |
| Offline | — | Cannot generate (needs network) | — |
| Success | Amount valid | QR/link displayed | Payment received |
| Pending | — | Waiting for payment | Payment detected, confirming |
| Expired | — | Invoice/offer expired | — |

---

## Continuity contracts

- Amount from entry persists in QR/link header
- Selected wallet badge visible throughout
- Payment method icon persists from selection to share screen
- Amount + method transition to confirmation summary

## Motion contract

- Forward: `KeroseneMotion.pageIn` (136ms)
- Method expand: `KeroseneMotion.medium` (260ms, easeOutCubic)
- Payment detected → confirmation: `KeroseneMotion.ceremonial` (Rive)
- NFC: `KeroseneMotion.nfcSceneIntro` (1600ms) → `KeroseneMotion.nfcSceneReady` (3900ms)

---

## Storybook coverage

| State | Story | Status |
|-------|-------|--------|
| Receive QR with amount | `Kerosene/App Flow` → `/receive/qr` | Exists |
| Receive payment link | `Kerosene/App Flow` → `/receive/payment-link` | Exists |
| Receive NFC | `Kerosene/App Flow` → `/receive/nfc` | Exists |
| On-chain confirming | `Kerosene/App Flow` → `/receive/onchain-confirming` | Exists |
| Invoice generation error | Not covered | Gap |
| Invoice expired | Not covered | Gap |
| Zero-amount (open invoice) | Not covered | Gap |
