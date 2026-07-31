# Flow: Send Money

> Status: Draft | Applies-to: mobile · web
> Anchors: `lib/features/movement/presentation/send/send_money_screen.dart`
> Last revised: 2026-07-31

## User objective chain

1. **Initiate:** "I want to send money"
2. **Source:** "Which wallet am I sending from?"
3. **Recipient:** "Who am I sending to?"
4. **Amount:** "How much?"
5. **Review:** "Is everything correct?"
6. **Authorize:** "I confirm this is me"
7. **Result:** "Did it work?"
8. **Detail:** "Show me the record"

Success metric per step:
1. User reaches send entry point from Home
2. Correct source wallet selected
3. Recipient identified (address, invoice, or contact)
4. Amount entered without errors
5. All parameters reviewed without confusion
6. Authorization completed
7. Result understood (success, pending, or failure)
8. Transaction detail accessible

---

## Screen sequence

```
Home
  │
  ├─→ [Wallet Selection] (modal, bottom-up)
  │     Entry: user taps wallet badge or "Send" without wallet selected
  │     Exit: wallet selected
  │     Dominant action: tap wallet row
  │     Motion: present bottom-up (260ms easeOutQuart)
  │
  ├─→ Send Entry
  │     Entry: wallet selected, user taps "Send"
  │     Exit: recipient entered OR method chosen
  │     Dominant action: paste/scan recipient
  │     Secondary: choose send method (on-chain, Lightning, internal)
  │     Motion: push right (136ms easeOutQuart)
  │
  ├─→ Amount Entry
  │     Entry: recipient valid
  │     Exit: amount entered and valid
  │     Dominant action: amount keyboard input
  │     Secondary: switch BTC/fiat, use max, fee options
  │     Motion: push right (136ms easeOutQuart)
  │
  ├─→ Review
  │     Entry: amount valid, recipient valid
  │     Exit: user confirms
  │     Dominant action: "Enviar R$ X" pill button
  │     Secondary: edit amount, source, recipient, fee
  │     Motion: push right (136ms easeOutQuart)
  │     Continuity: amount + recipient + fee maintain position from entry
  │
  ├─→ Authorization (PIN / Passkey)
  │     Entry: user taps confirm
  │     Exit: authorization success or failure
  │     Dominant action: PIN entry or passkey verification
  │     Motion: monochrome theme transition (secure loop)
  │     Technology: Rive state machine for passkey, monochrome theme for PIN
  │
  ├─→ Processing
  │     Entry: authorization success
  │     Exit: transaction submitted (success) or failure
  │     Dominant action: none (system processing)
  │     Motion: animated glyph → status transition (ceremonial)
  │     States: submitting, pending (mempool), confirming, failed
  │
  └─→ Result
        Entry: transaction resolved
        Exit: user acknowledges
        Dominant action: "Ver detalhes" (primary) or "Fechar" (secondary)
        Motion: ceremonial confirmation (2600ms) → summary
        States: success, pending, failed, network error
          │
          └─→ Transaction Detail (optional)
                Entry: user taps "Ver detalhes"
                Exit: user navigates back
                Dominant action: copy tx ID, view on explorer
```

---

## State matrix

| State | Send Entry | Amount Entry | Review | Authorization | Processing | Result |
|-------|-----------|-------------|--------|--------------|------------|--------|
| Loading | Validating recipient | Fetching fee estimate | — | — | Submitting | — |
| Empty | No recipient entered | No amount entered | — | — | — | — |
| Partial | Recipient entered, no amount | Amount entered, fee loading | Fee recalculating | — | — | — |
| Error | Invalid recipient | Amount exceeds balance | Insufficient funds | Auth failed | Network error | Tx failed |
| Offline | Recipient validation unavailable | Fee unavailable | Cannot submit | Auth works offline (PIN) | Cannot submit | Status unknown |
| Success | Recipient valid | Amount valid + fee shown | All parameters confirmed | Auth successful | Tx submitted | Tx confirmed |
| Pending | — | — | — | — | Tx in mempool | Tx pending |
| Duplicate | — | — | Duplicate detection warning | — | — | — |
| Expired | — | Invoice expired | Quote expired | Auth window expired | — | — |
| Cancelled | User dismisses | User goes back | User goes back | User cancels | — | — |

---

## Continuity contracts

### Amount value
- **Amount Entry → Review:** The numeric value must maintain its screen position. Use `Hero` or a shared `AnimatedNumberDisplay` that transitions from editable (Amount Entry) to confirmed (Review) without disappearing.
- **Review → Processing:** The amount stays visible during the authorization/processing animation. Never hide the amount during processing.
- **Processing → Result:** The amount appears in the result summary in the same typographic style (Playfair Display, w590).

### Recipient
- **Send Entry → Review:** Recipient address/label transitions from editable field to read-only summary. Maintain the same text content, same horizontal position.
- **Review → Result:** Recipient name/address appears in the result summary.

### Wallet (source)
- **Wallet Selection → Send Entry:** Selected wallet badge is visible throughout the flow. Shows: wallet name, custody type badge, available balance.
- **Send Entry → Review:** Wallet badge persists. Balance updates to reflect the outgoing amount after confirmation.

### Fee
- **Amount Entry → Review:** Fee appears during amount entry (reactive). Position: below amount, smaller type, tertiary color (Fog #8A8F98).
- **Review → Processing:** Fee is part of the confirmed summary. Does not change after authorization.

---

## Motion contract

### Page transitions
- Forward (push): `KeroseneMotion.pageIn` (136ms, easeOutQuart)
- Backward (pop): `KeroseneMotion.pageOut` (92ms, easeInCubic)
- Modal (wallet selector): `KeroseneMotion.medium` (260ms, easeOutQuart) bottom-up

### Button states
- Idle → Processing: `KeroseneMotion.fast` (120ms, easeOutCubic), button text fades to animated glyph
- Processing → Success: Rive state machine, ceremonial duration
- Processing → Error: `KeroseneMotion.medium` (260ms, easeOutCubic), button returns to idle with error shake

### Authorization
- PIN entry: monochrome theme transition (`KeroseneMotion.medium`, 260ms)
- Passkey: `KeroseneMotion.passkeyScene` (900ms) → `KeroseneMotion.passkeyPulse` (5000ms loop while waiting)

### Processing → Result
- Success: `KeroseneMotion.ceremonial` (2600ms, Rive state machine)
- Failure: `KeroseneMotion.medium` (260ms, easeOutCubic), error state appears
- Pending: `KeroseneMotion.status` (1500ms), status indicator with estimated time

---

## Accessibility contract

- Amount: `semanticLabel: 'Enviar R\$ {valor} para {destinatario}'`
- Review: all parameters announced in logical order (source, recipient, amount, fee, total)
- Authorization: PIN dots have `semanticLabel: 'PIN: {n} de 6 digitos inseridos'`
- Processing: `SemanticsService.announce` on status change
- Result: success/failure announced immediately
- Haptics: light on wallet select, medium on confirm tap, heavy on auth failure, double light on success

---

## Storybook coverage

| State | Story | Status |
|-------|-------|--------|
| Full happy path | `Kerosene/App Flow` → `/send-money` | Exists |
| Insufficient balance | Not covered | Gap |
| Invalid recipient | Not covered | Gap |
| Fee recalculation | Not covered | Gap |
| Authorization failure | Not covered | Gap |
| Network error during submit | Not covered | Gap |
| Duplicate detection | Not covered | Gap |
| Invoice expired | Not covered | Gap |

---

## Verification

- [ ] Does the amount maintain position from entry to review to result?
- [ ] Is the wallet badge visible throughout the flow?
- [ ] Are ALL states in the state matrix implemented or backlogged?
- [ ] Does the authorization step have its own screen/sheet (not inline dialog)?
- [ ] Does the processing animation tie to real transaction state (not decorative video)?
- [ ] Does `reduceMotion` collapse page transitions + remove button pulse?
- [ ] Are semantic labels present on amount, recipient, and PIN entry?
