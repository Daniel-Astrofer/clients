# Plano de ajuste — histórico e armazenamento de transações

**Base:** `TRANSACTION_HISTORY_STORAGE_ANALYSIS.md` + `LOCAL_LEDGER_SYNC.md`  
**Objetivo:** uma projeção de extrato coerente, confs confiáveis, menos divergência UI, e política de segurança local explícita.

---

## 1. Princípios do ajuste

1. **Uma projeção, um merge** — todo extrato/insight/home usa `LocalLedgerSync` / `LedgerMerge`.  
2. **Remoto vivo manda em confs/status** — `/kfe/transactions` > statement; statement nunca rebaixa confs.  
3. **Id estável** — PK = `transactionId` (UUID); nunca colapsar por `blockchainTxid` sozinho.  
4. **Política de dados no device explícita** — logout / wipe / multi-user documentados e implementados.  
5. **Incremental** — cada fase shippável sem big-bang.

---

## 2. Mapa problema → correção

| # | Inconsistência / insegurança | Correção | Fase |
|---|------------------------------|----------|------|
| I1 | Insights com merge por `chain:txid` | Usar `TransactionLedgerAdapter.mergeTransactionLists` | A |
| I2 | Statement como fonte de confs defasadas | Nunca preferir statement se API txs já respondeu (mesmo vazia com 200); marcar source; merge anti-regressão | A |
| I3 | Sem `updatedAt` no FE | Propagar `updatedAt` da API em `Transaction` + merge | A |
| I4 | Paged history fora da projeção | Page 0 via LocalLedgerSync; page>0 opcional ou descontinuar | B |
| I5 | Saldo ≠ extrato por alguns segundos | Invalidar histórico + wallet juntos; debounce único de refresh | B |
| I6 | Cap 500 opaco | UI “mostrando N de M” se API tiver total; doc de retenção | B |
| I7 | Logout **não** apaga extrato local | **Política fixa:** logout preserva `tx_history_v1:{scope}`; wipe só em ação explícita “apagar dados do aparelho” | C |
| I8 | Blob local sem integridade | HMAC opcional com chave de sessão | C |
| I9 | Background não atualiza extrato | Aceitar no MVP; ou sync mínimo no FG service (fase D) | D |
| I10 | PIN vs providers de extrato | Garantir gate antes de hidratar extrato | C |

---

## 3. Fases

### Fase A — Integridade do extrato (P0, 3–5 dias)

**Meta:** extrato e insights contam a mesma história; confs sobem e não “grudam” em 0 por cache.

| Tarefa | Detalhe | Arquivos principais |
|--------|---------|---------------------|
| A1 | Unificar merge de insights | `statement_insights_provider.dart` → chamar `TransactionLedgerAdapter` / `LocalLedgerSync` |
| A2 | Remover `mergeInsightTransactions` legado | ou marcar `@Deprecated` e redirecionar |
| A3 | Adicionar `updatedAt` opcional em `Transaction` | parse de JSON; fallback = `timestamp` |
| A4 | Adapter de merge usa `updatedAt` real | `transaction_ledger_adapter.dart`, `ledger_merge.dart` |
| A5 | Datasource: se `/kfe/transactions` retorna 200 com `[]`, **não** cair em statement sem flag | `ledger_remote_datasource.dart` — distinguir “lista vazia legítima” vs “erro de rede” |
| A6 | Tag de origem no merge | statement rows com `LedgerSource.statement` (já previsto) ao mapear fallback |
| A7 | Testes | T1–T8 + insights usam mesma chave; confs 0→6; inbound+outbound mesmo txid = 2 linhas |

**Critério de pronto**

- [ ] Insights e `transactionHistoryProvider` produzem o mesmo conjunto de ids para o mesmo input.  
- [ ] Cache local com 0 confs + API com N confs → UI mostra N após pull.  
- [ ] CI: `ledger_merge_test` + testes de insights.

**Não fazer nesta fase:** wipe logout, SQLite, background ledger.

---

### Fase B — Consistência de sync e superfícies (P1, 3–4 dias)

**Meta:** um fluxo de refresh; menos estados mistos saldo/lista.

| Tarefa | Detalhe |
|--------|---------|
| B1 | `FinancialRefreshCoordinator` (ou método único no notifier): `refreshFinancialState()` invalida history + wallets + deposits numa ordem fixa |
| B2 | WS notificação → chama só o coordinator (não 5 invalidates soltos) |
| B3 | Após send/pay/withdraw → mesmo coordinator |
| B4 | `pagedTransactionHistoryProvider`: page 0 = `LocalLedgerSync`; page>0 só se UI realmente paginar; senão deprecar |
| B5 | Home pull-to-refresh → coordinator |
| B6 | (Opcional) `GET /kfe/transactions?since=` se BE expuser; senão manter page 0 size 50–100 |

**Critério de pronto**

- [ ] Um único entrypoint de “dinheiro mudou” no FE.  
- [ ] Não há caminho de UI de extrato que ignore LocalLedgerSync.

---

### Fase C — Segurança e política de dados locais (P1, 2–4 dias)

**Meta:** confidencialidade e comportamento multi-user explícitos.

| Tarefa | Detalhe |
|--------|---------|
| C1 | **Logout NÃO apaga extrato** — `auth_local_datasource.clearAll` e qualquer path de logout **nunca** chamam `LocalTransactionHistoryStore.clear` / `LocalLedgerSync.clear` |
| C2 | Extrato fica em `tx_history_v1:user_{id}` — multi-user no mesmo device isola por scope; login do user A reidrata o extrato de A |
| C3 | Wipe opcional só em setting explícito **“Apagar extrato deste aparelho”** (não no logout) |
| C4 | App entry PIN: não `watch(transactionHistoryProvider)` antes do unlock (auditar home_loading / shell) |
| C5 | (Opcional) HMAC do blob: `payload + mac` com chave em secure storage por sessão; falha de mac → discard e re-pull |
| C6 | Build release: garantir que `debugPrint` sensíveis não vazam ids em massa |
| C7 | Histórico reativo como saldo: `refreshFinancialProjection` + WS balance/notification invalidam `transactionHistoryProvider` e re-pull |

**Critério de pronto**

- [x] Logout **não** apaga extrato local (política fixa).  
- [ ] Segundo user no mesmo device não vê extrato do primeiro (scope por user id).  
- [ ] Extrato não hidrata na tela de PIN.  
- [ ] Atualização reativa do extrato no mesmo caminho do saldo (WS + poll + send).

---

### Fase D — Robustez e evolução (P2, backlog)

| Tarefa | Detalhe |
|--------|---------|
| D1 | Propagar `updatedAt` em todo touch de confs no KFE (já parcial) + testes BE |
| D2 | Statement: sempre `refreshTransactionDisplayPayload` em conf touch (já iniciado) |
| D3 | Background: opcionalmente enfileirar “dirty flag” para full pull no próximo foreground |
| D4 | SQLite projection se cap 500 / performance virar problema |
| D5 | Endpoint incremental `since` + ETag |
| D6 | Telemetria: contagem de “merge confs upgraded”, “offline serve local”, “statement fallback used” |

---

## 4. Ordem de PRs sugerida

| PR | Conteúdo | Depende |
|----|----------|---------|
| **PR-A1** | Insights → LocalLedgerSync + testes | — |
| **PR-A2** | `Transaction.updatedAt` + merge + datasource empty-list | PR-A1 opcional paralelo |
| **PR-B1** | FinancialRefreshCoordinator + WS/send hooks | A estável |
| **PR-B2** | Paged history alinhado / cleanup | B1 |
| **PR-C1** | Enforce logout never wipes extract + reactive history | A |
| **PR-C2** | PIN gate audit + optional HMAC | C1 |
| **PR-D\*** | BE polish + background dirty + SQLite | backlog |

---

## 5. Detalhe técnico das mudanças críticas

### 5.1 Insights (A1)

**Antes**

```dart
// key = chain:txid  → colapsa inbound/outbound
mergeInsightTransactions(remote, local);
```

**Depois**

```dart
final merged = await LocalLedgerSync(store).hydrateAndMerge(
  sessionScope: scope,
  remote: remote, // já é projeção do history provider
);
// ou, se insights só precisa da lista do history:
final transactions = await ref.watch(transactionHistoryProvider.future);
// sem segundo merge
```

Preferência: **insights só leem `transactionHistoryProvider`**, zero merge próprio.

### 5.2 Datasource empty list (A5)

```text
GET /kfe/transactions → 200 []
  → retornar []  (NÃO fallback statement)

GET /kfe/transactions → network/5xx
  → fallback statement (marcada source=statement)
  → merge local com anti-regressão de confs
```

### 5.3 Logout wipe (C1)

```text
logout():
  scope = currentScope
  if (!keepHistoryOnLogout) await store.clear(scope)
  clear tokens / auth state
```

### 5.4 Coordinator (B1)

```text
refreshFinancialState(reason):
  invalidate/refresh wallets
  invalidate/refresh transactionHistory  // LocalLedgerSync inside
  invalidate deposits / payment links as needed
  optional: single flight mutex so WS storms collapse
```

---

## 6. Testes por fase

| Fase | Testes obrigatórios |
|------|---------------------|
| A | Unit merge T1–T8; insights = same ids as history; updatedAt regression |
| B | Widget/provider: uma notificação WS → um refresh coordenado (mock) |
| C | Logout wipe limpa chave; keep history preserva; segundo user scope isolado |
| D | BE conf touch updates statement + list |

---

## 7. Rollout e validação manual

1. Rebuild app com Fase A.  
2. Conta com cold + custodial: envio Electrum, confs sobem no extrato **e** nos insights.  
3. Airplane mode: extrato antigo aparece.  
4. Logout/login mesmo user: extrato volta (se keep on).  
5. Logout com wipe: extrato some.  
6. Dois users no device: sem vazamento de extrato.

---

## 8. O que **não** fazer no ajuste

- Reescrever todo o Riverpod de uma vez.  
- Introduzir SQLite antes de unificar merge (complexidade sem ganho se A/B não estiverem ok).  
- Apagar histórico remoto no KFE.  
- FCM como substituto de projeção local.

---

## 9. Esforço e prioridade

| Fase | Esforço | Impacto em inconsistência | Impacto em segurança |
|------|---------|---------------------------|----------------------|
| **A** | 3–5 d | **Alto** | Médio (integridade) |
| **B** | 3–4 d | **Alto** (UX/sync) | Baixo |
| **C** | 2–4 d | Baixo | **Alto** |
| **D** | backlog | Médio | Médio |

**Ordem recomendada:** A → C (wipe + PIN) em paralelo com B se houver duas pessoas; senão A → B → C → D.

---

## 10. Definition of done (sistema)

- [ ] Uma única função de merge no FE para extrato.  
- [ ] Confs da UI = confs da API de txs após pull (não statement velho).  
- [ ] Inbound+outbound mesmo txid = 2 linhas em home, extrato e insights.  
- [ ] Offline: last projection; online: merge sem regressão de confs.  
- [ ] Política de logout/wipe documentada na UI de settings.  
- [ ] Testes A+C verdes no CI.

---

## 11. Primeiro PR concreto (começar aqui)

**PR-A1 + A7:**  
Remover merge legado de insights; insights consomem só `transactionHistoryProvider`; testes de paridade.

**PR-A2:**  
`updatedAt` + datasource empty-list + testes de anti-regressão.

Depois disso o app já elimina a maior parte das **inconsistências visíveis** de histórico. A fase C fecha a maior parte das **inseguranças de confidencialidade local**.
