# LocalLedgerSync — design de projeção local + remota

**Status:** In tree (PR1–PR4) — merge, store, history provider, balance display cold vs custodial.  
**Área:** Flutter FE + contratos KFE/dashboard  
**Problema:** extrato, confirmações e saldos divergem entre cache local, statements congelados e `transactions_master` ao vivo.

---

## 1. Context and goals

### 1.1 Context

O Kerosene FE mantém:

1. **Remoto vivo** — `/kfe/transactions`, balances, WebSocket de saldo/notificações.  
2. **Remoto curto** — statements do dashboard (`displayPayloadJson`, ~24h).  
3. **Local durable** — `LocalTransactionHistoryStore` (secure storage, por sessão).

Hoje o merge é ad hoc: chaves por `blockchainTxid` colidem (inbound+outbound), score de “riqueza” quase ignora `confirmations`/`status`, e o statement congela confs na criação. O usuário vê loading infinito em 0 confs mesmo com cadeia/API atualizadas.

### 1.2 Goals

1. **Uma projeção local** legível pela UI (lista + detalhe + saldos por wallet).  
2. **Regras de merge field-level** explícitas e testáveis.  
3. **Identidade estável de linha** = `transactionId` (UUID KFE).  
4. **Remote wins** em estado vivo (confs, status, amounts, updatedAt).  
5. **Local keeps** linhas que o remoto já esqueceu (janela 24h / offline).  
6. Conflitos cobertos por testes: 0 vs 6 confs; inbound+outbound mesmo txid; offline→online.

### 1.3 Non-goals

- Sync multi-dispositivo / CRDT.  
- Substituir o modelo dual custodial (`available` vs `observed`) — só **expor** com clareza.  
- FCM/APNs.  
- Reescrever todo o Riverpod de uma vez (migração incremental por PRs).

---

## 2. Key decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Row id = `transactionId` UUID** | Cada linha KFE é única; `blockchainTxid` sozinho colide inbound/outbound. |
| D2 | **Projeção local é a única fonte da UI de extrato** | Evita telas lendo API crua + cache em caminhos diferentes. |
| D3 | **Field ownership** | Remoto manda em confs/status/amounts/updatedAt; local manda em “presença de linha antiga”. |
| D4 | **`updatedAt` monotônico do servidor** | Desempate sem heurísticas de score frágeis. |
| D5 | **Events + full pull** | WS/notificação invalidam por id; pull periódico rehidrata lista. |
| D6 | **Statements = fallback**, nunca autoridade de confs | Payload congelado não pode vencer `/kfe/transactions`. |
| D7 | **Saldos fora do merge de txs** | Wallet balances têm snapshot próprio (`available` / `observed` / kind). |

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Remote                                                    │
│  GET /kfe/transactions (page)  → TransactionDto[]         │
│  GET dashboard                 → wallets + statements*    │
│  WS /queue/...                 → balance, notification    │
│  *statements only if transactions empty / error           │
└────────────────────────┬─────────────────────────────────┘
                         │ apply(RemoteBatch | RemoteEvent)
┌────────────────────────▼─────────────────────────────────┐
│ LocalLedgerSync (domain service, pure + IO adapter)       │
│  - InMemory + SecureStorage projection                    │
│  - merge rules                                            │
│  - emit ProjectionSnapshot                                │
└────────────────────────┬─────────────────────────────────┘
                         │ watch()
┌────────────────────────▼─────────────────────────────────┐
│ UI (Riverpod)                                             │
│  transactionHistoryProvider → ProjectionSnapshot.txs      │
│  wallet cards → ProjectionSnapshot.balances               │
└──────────────────────────────────────────────────────────┘
```

### 3.1 Components

| Component | Responsibility |
|-----------|----------------|
| `LedgerRow` | Modelo de projeção (id, direction, rail, confs, status, wallets, amounts, chain ids, timestamps, source). |
| `BalanceSnapshot` | Por `walletId`: kind, available, observed, pending, locked, `updatedAt`. |
| `LocalLedgerStore` | Persistência (secure storage) + load/save atômico. |
| `LocalLedgerSync` | Apply remote batch/event; merge; persist; notify. |
| `LedgerRemoteGateway` | HTTP/WS adapters (já existentes, encapsulados). |
| Providers | Só assinam `LocalLedgerSync.watch()`. |

---

## 4. Data model

### 4.1 `LedgerRow` (projeção)

```text
LedgerRow {
  id: String                 // KFE UUID — PRIMARY KEY
  direction: inbound|outbound|internal
  rail: onchain|lightning|internal
  status: pending|confirming|confirmed|failed|cancelled
  confirmations: int         // chain confs; 0 = mempool/unknown
  amountSats: int
  feeSats: int
  serviceFeeSats: int
  sourceWalletId?: String
  destinationWalletId?: String
  blockchainTxid?: String
  externalReference?: String
  provider?: String
  memo?: String
  createdAt: DateTime        // event time (UTC→local na UI)
  updatedAt: DateTime        // server monotonic merge key
  localOnly: bool            // true se nunca veio do remoto nesta sessão
  tombstone: bool            // reserved (future soft-delete)
}
```

### 4.2 Identity and secondary indexes

| Index | Use |
|-------|-----|
| **PK** `id` | Merge, update, WS |
| **Secondary** `(blockchainTxid, direction)` | Debug / deep-link; **nunca** PK |
| **Secondary** `walletId ∈ {source, dest}` | Filtro por conta |

### 4.3 Balance snapshot

```text
BalanceSnapshot {
  walletId, kind, label,
  availableSats, observedSats, pendingSats, lockedSats,
  updatedAt
}
```

UI rules (display only):

| Kind | Primary amount shown |
|------|----------------------|
| `WATCH_ONLY` | `observedSats` |
| `CUSTODIAL_ONCHAIN` | `availableSats` (+ optional subtitle “na rede: observed”) |
| `INTERNAL` | `availableSats` |

---

## 5. Merge policy (field-level)

### 5.1 Apply remote row `R` onto local row `L` (same `id`)

| Field | Winner | Rule |
|-------|--------|------|
| `confirmations` | max(L, R) if same epoch; else **R if R.updatedAt ≥ L.updatedAt** | Never decrease confs unless remote `updatedAt` is strictly newer **and** remote explicitly resets (rare; log) |
| `status` | Remote if `R.updatedAt ≥ L.updatedAt` | Prefer “later” status; block downgrade confirmed→pending unless newer remote |
| amounts / fees | Remote if newer `updatedAt` | |
| addresses / memo / provider | Remote if newer; else keep local non-empty | Fill-empty |
| `createdAt` | min / first non-null | Stable sort key |
| `updatedAt` | max | |
| `localOnly` | false if any remote applied | |

**Default if timestamps equal:** prefer higher `confirmations`, then “more terminal” status (`confirmed` > `confirming` > `pending`).

### 5.2 Insert

- Remote id unknown locally → insert.  
- Local-only id never seen remotely → keep until TTL policy (e.g. 90 days) or user clear.

### 5.3 No cross-id collapse

Two rows with same `blockchainTxid` and different `id` **both stay**.  
UI may group them in detail (“mesma tx on-chain”) later — out of scope.

### 5.4 Statement fallback

When hydrating from statement payload only:

- Map to `LedgerRow` with `updatedAt = createdAt` (or statement time).  
- Tag `source=statement`.  
- A later `/kfe/transactions` row with same `id` **always** replaces confs/status.

### 5.5 Forbidden heuristics (remove)

- Dedupe key = only `blockchainTxid`.  
- Completeness score that ignores confs.  
- Prefer older timestamp when scores equal (old bug).

---

## 6. Sync states

```text
                    ┌─────────┐
                    │  idle   │
                    └────┬────┘
           app start / login / resume
                         │
                    ┌────▼────┐
              ┌─────┤ hydrating│◄──── pull page 0..N
              │     └────┬────┘
              │          │ success
              │     ┌────▼────┐
              │     │  live   │◄──► WS events + debounce pull
              │     └────┬────┘
              │          │ network error
              │     ┌────▼────┐
              │     │ offline │── serve projection only
              │     └────┬────┘
              │          │ reconnect
              │          └──► hydrating
              │
              └── failure with empty remote + non-empty local → offline
```

| State | Behavior |
|-------|----------|
| `hydrating` | Load secure store → pull remote → merge → persist → `live` |
| `live` | Apply WS; periodic soft pull (e.g. 30–60s) or on notification |
| `offline` | UI reads projection; badge “offline”; no destructive wipe |

---

## 7. Event application

| Event | Action |
|-------|--------|
| `notification` entityType=transaction, entityId=X | Soft-fetch tx X or full page 0; merge |
| `balance` WS | Update `BalanceSnapshot` for wallet key |
| Pull-to-refresh | Full page 0 (+ page 1 if needed); merge |
| Logout | Clear session scope storage |

---

## 8. API contract additions (minimal)

Prefer existing fields; require:

1. **`id`** always present and stable.  
2. **`confirmations`** integer on every on-chain row.  
3. **`updatedAt`** ISO-8601 with `Z` (same Instant policy as `createdAt`).  
4. List endpoint authoritative over dashboard statement for history.

KFE already exposes list + Instant timestamps; ensure `updatedAt` is bumped on every conf touch (already true via entity `@PreUpdate` / explicit sets).

**Optional later:** `GET /kfe/transactions?since=ISO` for incremental sync.

---

## 9. Conflict scenarios and tests

### 9.1 Unit tests (pure merge)

| # | Scenario | Given | Expect |
|---|----------|-------|--------|
| T1 | **0 confs vs 6 confs** | Local row confs=0, updatedAt=t0; Remote confs=6, updatedAt=t1>t0 | confs=6, status confirmed/confirming per remote |
| T2 | **Stale remote confs** | Local confs=6, updatedAt=t2; Remote confs=0, updatedAt=t1<t2 | keep confs=6 (do not regress) |
| T3 | **Inbound + outbound same txid** | Two remote rows, same `blockchainTxid`, different `id`, opposite direction | **two** projection rows |
| T4 | **Offline→online** | Local-only empty; local has 3 rows; remote returns 2 overlapping + 1 new | 3–4 rows: union by id; overlapping take remote confs |
| T5 | **Statement then live** | Hydrate from statement confs=0; then transactions API confs=3 same id | confs=3 |
| T6 | **Equal updatedAt** | confs 1 vs 4, same updatedAt | confs=4 |
| T7 | **Wallet filter** | Rows for wallets A,B | filter(A) only A |
| T8 | **Balance kinds** | WATCH_ONLY observed=100, available=0 | display primary=100 |

### 9.2 Integration (optional)

- Mock gateway: page returns VALIDATING 0 confs; later page returns SETTLED 3 confs; provider emits second snapshot with 3.  
- Secure storage round-trip: serialize/deserialize preserves ids and confs.

### 9.3 Manual QA checklist

1. Electrum spend cold → app shows outbound; confs climb after blocks.  
2. Electrum → custodial address → inbound custodial + available increase.  
3. Kill network → open app → history still visible.  
4. Restore network → confs catch up without wiping history.  
5. Same chain tx producing cold change inbound + outbound → **two** cards.

---

## 10. Migration from current code

| Current | Target |
|---------|--------|
| `LocalTransactionHistoryStore._historyKey` | PK = `transaction:${id}` only |
| Logout | **Never** clears `tx_history_v1:*` — extract survives re-login |
| UI networks | Classify INTERNAL / cold / on-chain / Lightning / payment-link (interno vs on-chain) for De/Para + filters |
| `_historyCompletenessScore` / `_score` | Replace with field-level merge + `updatedAt` |
| `transactionHistoryProvider` merge | Delegate to `LocalLedgerSync.hydrateAndPull()` |
| Dashboard statement path | Fallback only; never preferred if transactions non-empty |
| Ring UI | Bound to `LedgerRow.confirmations` from projection |

**Compat:** on first load after upgrade, re-key existing JSON: if id present, use it; drop ambiguous `blockchain:`-only duplicates by preferring higher confs then newer status (one-time migration in store load).

---

## 11. Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| **Remote-only, no local** | Breaks 24h statement retention product need |
| **Local-only CRDT multi-device** | Overkill; no multi-device requirement yet |
| **SQLite full ledger** | Better long-term; higher cost — phase 2 after sync rules proven in secure JSON |
| **Score-based merge forever** | Already failed in production (0 confs stuck) |

---

## 12. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Missing `updatedAt` on some DTOs | Fallback: treat remote as newer on every successful pull for that id |
| Duplicate UUIDs (bug) | Assert unique; log + prefer higher confs |
| Storage size | Cap 500 rows (existing); drop oldest by `createdAt` |
| WS storm | Debounce apply 300–500ms |

---

## 13. Open questions

1. **TTL de linhas só-local:** 90 dias vs forever até cap 500?  
2. **SQLite na fase 2** ou manter secure JSON no MVP de sync?  
3. **UI de saldo custodial:** sempre mostrar observed como subtítulo?

Defaults propostos se não houver resposta: TTL=cap 500 only; JSON MVP; subtítulo observed em custodial.

---

## 14. PR Plan

### PR1 — Domain model + pure merge + tests
- **Files:** `lib/features/ledger/domain/ledger_row.dart`, `ledger_merge.dart`, `balance_snapshot.dart`, tests under `test/features/ledger/`  
- **Deps:** none  
- **Desc:** `LedgerRow`, merge rules T1–T8 without Flutter storage.

### PR2 — Store + migration + LocalLedgerSync IO
- **Files:** replace/adapt `local_transaction_history_store.dart`, new `local_ledger_sync.dart`  
- **Deps:** PR1  
- **Desc:** persistence, re-key migration, hydrate/pull API.

### PR3 — Wire providers + kill bad merge paths
- **Files:** `transaction_provider.dart`, ledger datasource preference already OK; remove blockchain-only keys  
- **Deps:** PR2  
- **Desc:** history UI reads projection only.

### PR4 — Balance snapshot clarity
- **Files:** wallet/dashboard mapping widgets  
- **Deps:** PR2  
- **Desc:** display rules cold vs custodial.

### PR5 — KFE polish (if gaps remain)
- **Files:** ensure `updatedAt` on conf touch; statement refresh already partially done  
- **Deps:** none (can parallel PR1)  
- **Desc:** remote contract reliability for merge.

**Suggested order:** PR5 ∥ PR1 → PR2 → PR3 → PR4.

---

## 15. Success metrics

- Zero stuck “yellow spin” when API returns `confirmations ≥ 1` after rebuild.  
- Inbound+outbound same txid: 2 rows in history.  
- Offline open → ≥1 screen of history if previously synced.  
- Merge unit tests green in CI.
