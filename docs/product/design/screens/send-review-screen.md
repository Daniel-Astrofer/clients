# Screen: Send Review

> Status: Draft | Applies-to: mobile · web
> Anchor: `lib/features/movement/presentation/send/send_money_screen.dart`
> Last revised: 2026-07-31

## User goal

Confirm that source, recipient, amount, fee, and speed are all correct before authorizing.

## Dominant question

"Exactly how much will leave, from where, and to whom?"

## Dominant action

"Enviar R$ {valor}" — outlined pill button, primary. This transitions into the authorization step.

## Secondary actions
- Edit amount (navigate back to Amount Entry)
- Edit recipient (navigate back to Send Entry)
- Change fee/speed (inline or sub-screen)
- Cancel (ghost button, returns to Home)

---

## Information hierarchy

1. **Amount + currency** — Playfair Display, 32px, w590, #F7F8F8. The largest element.
2. **Recipient** — Label or truncated address, 15px, w400, #D0D6E0 (Mist).
3. **Source wallet** — Wallet name + custody badge, 15px, w400.
4. **Fee** — Amount + fiat equivalent, 13px, #8A8F98 (Fog).
5. **Total debited** — Amount + fee, 15px, w590, #F7F8F8.
6. **Speed estimate** — Text, 12px, #62666D (Steel).

---

## All states

| State | Behavior |
|-------|----------|
| **Complete** | All parameters shown, confirm button enabled |
| **Fee recalculating** | Fee row shows spinner + "Recalculando taxa...", confirm button disabled |
| **Insufficient balance** | Error banner: "Saldo insuficiente. Disponivel: R$ X. Necessario: R$ Y." Confirm button disabled |
| **Invalid recipient** | Should not reach review — validated at Send Entry. If reached, error banner + back navigation |
| **Network unavailable** | Fee may be stale. Warning: "Taxa pode estar desatualizada. Rede indisponivel." |
| **Authorization expired** | Not applicable at review step (expires during authorization) |
| **High-risk operation** | Warning banner: "Valor alto. Verifique o endereco cuidadosamente." Does not block confirmation. |
| **Offline** | Cannot submit. Confirm button disabled. "Sem conexao. Tente novamente quando estiver online." |
| **Duplicate detected** | Warning banner: "Voce enviou para este endereco recentemente. Confirmar mesmo assim?" |
| **Quote expired** | Fee expired. "Taxa expirada. Atualizando..." → auto-refresh or manual retry. |

---

## Continuity

### From Amount Entry
- **Amount value:** Hero transition from editable field to confirmed display. Same typography (Playfair, w590). Same position perceptually.
- **Recipient:** Transitions from input field to read-only label. Same text. Same horizontal position.
- **Fee:** Already displayed in Amount Entry. Transitions to review summary row. Same position (below amount).

### To Authorization
- **Total amount:** Persists in authorization header: "Enviar R$ X"
- **Button:** Transitions from idle → processing (animated glyph). Does not disappear.

### To Result
- **Amount + recipient + source:** Appear in result summary in same typographic style.
- **Fee + total:** Appear in result detail.

---

## Motion contract

- **Entry:** `KeroseneMotion.pageIn` (136ms, easeOutQuart)
- **Amount Hero:** 260ms, easeOutExpo (from Amount Entry's editable field to Review's confirmed display)
- **Fee recalculation:** Fee row slides height, no opacity flicker
- **Error banner appearing:** `KeroseneMotion.medium` (260ms, easeOutQuart), slides down from top
- **Confirm → Authorization:** Button transitions to processing state: 120ms text fade → animated glyph. Then push to authorization screen (or inline PIN sheet).
- **Back:** `KeroseneMotion.pageOut` (92ms, easeInCubic) — amount Hero reverses

---

## Accessibility contract

- Amount: `semanticLabel: 'Enviar {valor} {moeda}'`
- Recipient: `semanticLabel: 'Para: {endereco ou nome}'`
- Source: `semanticLabel: 'De: carteira {nome}'`
- Fee: `semanticLabel: 'Taxa: {valor}'`
- Total: `semanticLabel: 'Total debitado: {valor}'`
- Confirm button: `semanticLabel: 'Confirmar envio de {valor}'`
- Error banners: announced via `SemanticsService.announce()`

---

## Performance contract

- No jank during Hero transition (test in profile mode)
- Fee recalculation must not trigger full screen rebuild
- Error banner uses `AnimatedContainer` (composited), not full rebuild

---

## Golden contract

5 resolutions as standard. States to capture: complete, fee recalculating, insufficient balance, duplicate warning.

---

## Verification

- [ ] Amount maintains position from entry to review?
- [ ] All error states show what happened + why + action?
- [ ] Confirm button transitions through states (idle → processing → success/error)?
- [ ] Fee is shown and clearly labeled?
- [ ] Total debited equals amount + fee?
- [ ] Hero transition works in both directions?
