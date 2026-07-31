# Screen: Transaction Detail

> Status: Draft | Applies-to: mobile · web
> Anchor: Movement activity detail
> Last revised: 2026-07-31

## User goal

Inspect all details of a specific transaction.

## Dominant question

"What exactly happened in this transaction?"

## Dominant action

Copy transaction ID (primary, for sharing/support). View on block explorer (secondary).

## Secondary actions
- Share receipt
- Repeat payment (if outgoing)
- View on block explorer (if on-chain)
- Report issue

---

## Information hierarchy

1. **Amount + direction** — Playfair Display, 32px, w590. Green (incoming) or Snow (outgoing).
2. **Status badge** — Confirmed/Pending/Failed + confirmation count if on-chain.
3. **Counterparty** — Address or label, truncated with copy. JetBrains Mono for address.
4. **Date & time** — 13px, #8A8F98 (Fog).
5. **Fee** — Amount + fiat equivalent.
6. **Transaction ID** — JetBrains Mono, truncated, with copy button.
7. **Confirmations** (on-chain) — Count + progress indicator.
8. **Block height / timestamp** — Metadata.
9. **Source wallet** — Wallet name + custody type.

---

## All states

| State | Behavior |
|-------|----------|
| **Loading** | Skeleton for detail fields (this is a valid skeleton case — no previous state) |
| **Confirmed** | Full detail, green status badge, confirmation count |
| **Pending** | Full detail, amber status badge, "0 confirmacoes" or "Aguardando" |
| **Failed** | Full detail, red status badge, failure reason |
| **Cancelled** | Full detail, grey status badge, cancellation info |
| **Offline** | Cached detail (if available) + "Offline — dados podem estar desatualizados" badge |
| **Error** | Failed to fetch detail, retry button |
| **Lightning** | No confirmations, shows "Instantaneo" instead, lightning badge |
| **Internal (ledger)** | No tx ID, shows "Interno Kerosene", instant status |
| **Cold wallet** | Shows PSBT status, signing progress |

---

## Continuity

### From Activity List
- Hero: transaction row (amount + counterparty + status) → detail header.
- Row position preserved for back navigation.

### From Payment Result
- Amount + counterparty + status carried directly.
- No Hero needed (result screen already shows summary).

---

## Motion contract

- Entry (from list): `KeroseneMotion.pageIn` (136ms) + Hero (260ms, easeOutExpo)
- Entry (from result): `KeroseneMotion.pageIn` (136ms), no Hero needed
- Copy confirmation: brief notice "Copiado" (3s hold, auto-dismiss)
- Block explorer: external link, system browser transition

---

## Accessibility contract

- Amount: `semanticLabel: '{Recebido/Enviado}: {valor}'`
- Status: `semanticLabel: '{status}. {n} confirmacoes.'`
- Counterparty: `semanticLabel: '{"Para/De"}: {endereco ou nome}'`
- Tx ID: `semanticLabel: 'ID da transacao: {id}'`, copy button: `semanticLabel: 'Copiar ID'`
- Fee: `semanticLabel: 'Taxa: {valor}'`
- Copy feedback: announce "ID copiado"

---

## Golden contract

States: confirmed (on-chain), confirmed (Lightning), pending, failed, internal ledger.

---

## Verification

- [ ] Amount + direction immediately clear?
- [ ] Status badge visible with confirmation count?
- [ ] Transaction ID is monospaced (JetBrains Mono)?
- [ ] Copy button works with confirmation feedback?
- [ ] Hero transition works from activity list?
- [ ] Block explorer link works for on-chain transactions?
- [ ] All states in matrix implemented or backlogged?
