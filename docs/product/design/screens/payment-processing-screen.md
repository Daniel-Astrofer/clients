# Screen: Payment Processing

> Status: Draft | Applies-to: mobile · web
> Anchor: Authorization → Processing → Result transition
> Last revised: 2026-07-31

## User goal

Wait for the transaction to be submitted and confirmed, understanding what is happening.

## Dominant question

"Did my payment go through?"

## Dominant action

None during processing. After result: "Ver detalhes" (primary) or "Fechar" (secondary).

## Secondary actions (post-result)
- View transaction detail
- Share receipt
- Return to Home
- Retry (on failure)

---

## Processing sequence

```
Authorization Success
  │
  ├─→ Submitting (0-2s)
  │     Visual: amount + "Enviando..." + animated glyph
  │     Motion: button processing state continues
  │
  ├─→ Pending (2s-??)
  │     Visual: "Aguardando confirmacao" + status indicator
  │     Motion: status pulse (1500ms loop)
  │     On-chain: "X de Y confirmacoes"
  │     Lightning: typically instant
  │
  ├─→ Success
  │     Visual: confirmation Rive animation + "Enviado: R$ X para Y"
  │     Motion: ceremonial (2600ms) → summary card
  │     Action: "Ver detalhes" appears after ceremony
  │
  └─→ Failure
        Visual: error icon + "Falha ao enviar" + reason + retry
        Motion: error transition (260ms easeOutCubic) — no ceremonial
        Action: "Tentar novamente" (primary) + "Fechar" (secondary)
```

---

## All states

| State | Visual | User action |
|-------|--------|------------|
| **Submitting** | Amount displayed, animated glyph, "Enviando..." | None (wait) |
| **Pending (mempool)** | Amount, "Aguardando confirmacao", confirmation counter | None (wait) |
| **Success** | Rive confirmation, amount + recipient summary | View detail, close |
| **Success (Lightning, instant)** | Same but faster — skip pending phase | View detail, close |
| **Failure (network)** | Error: "Falha de rede. Verifique sua conexao." | Retry |
| **Failure (rejected)** | Error: "Transacao rejeitada: {reason}" | Close, view detail |
| **Failure (timeout)** | Error: "Tempo excedido. A transacao pode ter sido enviada." | View detail, retry |
| **Failure (insufficient funds at submit)** | Error: "Saldo insuficiente apos taxa." | Change amount, close |
| **Offline** | Cannot reach network. "Sem conexao." Retry pulse every 4s. | Retry, close |

---

## Continuity

### From Authorization
- Amount + recipient visible throughout processing. Never hidden.
- Button transitions seamlessly: idle → processing glyph → success/failure.

### To Transaction Detail
- Amount + recipient + fee + status carry to detail header.
- Hero: status icon from result → detail header.

---

## Motion contract

**CRITICAL: Processing animation MUST be tied to real transaction state.** Rive state machine inputs:
- `isSubmitting` (bool) → submitting animation
- `isPending` (bool) → pending/mempool animation
- `isConfirmed` (bool) → success animation
- `errorCode` (string) → failure animation

The Rive animation must NOT play as a fixed-duration video. It must react to real state changes from the transaction provider.

- Submitting → Pending: 260ms transition
- Pending → Success: Rive ceremonial (2600ms)
- Pending → Failure: 260ms, easeOutCubic — fast, no celebration
- Timeout: after `KeroseneMotion.loadingTimeout` (15s), show timeout state

---

## Accessibility contract

- Submitting: `semanticLabel: 'Enviando {valor} para {destinatario}'`
- Pending: `semanticLabel: 'Aguardando confirmacao. {n} de {total} confirmacoes.'`
- Success: `SemanticsService.announce('Enviado com sucesso: {valor}')`
- Failure: `SemanticsService.announce('Falha ao enviar: {motivo}')`
- Haptics: double light on success, heavy on failure

---

## Performance contract

- Rive animation must not drop frames during state transitions
- Processing screen must maintain 60fps
- If Rive machine is heavy, use a simplified Flutter animation for lower-end devices (detect via `PlatformDispatcher`)

---

## Golden contract

States to capture: submitting, pending, success, failure, timeout.

---

## Verification

- [ ] Processing animation tied to real transaction state (not fixed video)?
- [ ] Amount + recipient visible throughout?
- [ ] Rive state machine responds to all 4 inputs?
- [ ] Timeout state reached after 15s?
- [ ] reduceMotion: ceremonial plays accelerated, functional uses instant?
- [ ] Success and failure have distinct haptic feedback?
