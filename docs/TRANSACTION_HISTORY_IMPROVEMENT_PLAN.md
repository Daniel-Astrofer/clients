# Plano de evolução — extrato, segurança e exposição segura de txs

**Base:** implementação atual (LocalLedgerSync PR1–PR4 + classificação de rede + refresh reativo + logout preserva extrato).  
**Objetivo:** fechar o que ainda é sensível/inseguro, melhorar UX de “de onde veio / para onde foi”, e expor o que o backend já envia de forma **segura, legível e consistente**.

---

## 0. O que já está razoavelmente bem

| Área | Estado |
|------|--------|
| Projeção local cifrada por user (`tx_history_v1:user_{id}`) | OK |
| Logout **não** apaga extrato | OK (política fixa) |
| Classificação de rede (interna / cold / on-chain / link / LN) | OK (v1) |
| De/Para + “Sua carteira” + rota no card | OK (v1) |
| Refresh extrato junto com saldo (WS / pull / pós-envio) | OK (parcial — ainda há invalidates soltos) |
| Preferência `/kfe/transactions` sobre statement 24h | OK |
| Merge principal por `transactionId` + confs | OK |

O plano abaixo **não reabre** a decisão de preservar extrato no logout.

---

## 1. Mapa de riscos restantes (sensível / inseguro / inconsistente)

### 1.1 Segurança e privacidade (device + API)

| ID | Risco | Severidade | Por quê |
|----|-------|------------|---------|
| **S1** | Blob local sem integridade (HMAC) | Média | Secure storage protege at-rest no OS, mas não detecta corrupção/tamper do JSON se o storage for comprometido |
| **S2** | Extrato legível após unlock de device, sem re-PIN | Média | App pode hidratar `transactionHistoryProvider` antes do PIN de app (se existir gate de entry) |
| **S3** | Multi-user no mesmo aparelho | Média | Scope `user_{id}` isola chaves; se scope cair para `username_*` ou guest, risco de colisão |
| **S4** | Campos internos de infra no client | Média | API devolve `quorumProposalHash`, `quorumAckCount`, `providerReference`, `failureMessage` crus — podem vazar detalhes de orquestração ou stack em falha |
| **S5** | `debugPrint` / logs em release | Baixa–Média | Paths de WS e history ainda logam contexto; em release builds com logging, endereços/ids podem vazar |
| **S6** | Screenshots / app switcher | Baixa | Extrato e saldos em claro na task switcher; sem `FLAG_SECURE` seletivo |
| **S7** | Payment link + KFE row duplicados | Baixa UX / Médio dados | Mesmo pagamento pode aparecer como `pl_*` e UUID KFE — confusão e double-count em insights |
| **S8** | Wipe só via clear OS | Baixa produto | Falta setting “Apagar extrato deste aparelho” (logout intencionalmente não apaga) |
| **S9** | Cap 500 silencioso | Baixa | Usuário não sabe que txs antigas sumiram do device (servidor ainda tem) |

### 1.2 Integridade de projeção (ainda inconsistente)

| ID | Risco | Severidade | Por quê |
|----|-------|------------|---------|
| **I1** | Insights com merge legado `chain:txid` | **Alta** | `mergeInsightTransactions` ainda colapsa inbound+outbound e diverge do extrato |
| **I2** | Sem `updatedAt` na entidade FE | Alta | Merge usa `timestamp`/createdAt; conf touch no BE pode não “vencer” o relógio de merge |
| **I3** | Paged history fora do LocalLedgerSync | Média | Page >0 ou page0 paralela pode divergir |
| **I4** | Full pull em vez de merge por evento | Média | WS invalida tudo; race / custo / confs momentaneamente “piscam” |
| **I5** | Statement 24h como fallback | Média | Payload congelado pode reintroduzir confs/labels fracos se path de fallback for usado |
| **I6** | Invalidates ainda espalhados | Baixa–Média | `refreshFinancialProjection` existe, mas send/home ainda tem listas manuais de invalidate |

### 1.3 Lacunas de UX / exposição do backend

| ID | Lacuna | Impacto no usuário |
|----|--------|--------------------|
| **U1** | Backend **não envia** `senderDisplayName` / `receiverDisplayName` no `KfeTransactionResponse` | De/Para internos dependem de resolver UUID de wallet no client — falha se carteira sumiu da lista |
| **U2** | Labels de wallet só no client | Offline sem lista de wallets → “Carteira global” genérico |
| **U3** | `provider` exposto cru na API, pouco humanizado | Cold/onchain ok na classificação; falhas e providers desconhecidos ainda viram “Rede desconhecida” |
| **U4** | `failureCode` / `failureMessage` não modelados no FE | Tx falha sem motivo legível |
| **U5** | `memo` livre vs labels de produto | Memo do user pode sobrescrever “Link de pagamento (on-chain)” se vier vazio do FE mas rico no BE |
| **U6** | Sem agrupamento visual por rede no feed “Tudo” | Filtros existem; lista “Tudo” ainda é cronológica pura |
| **U7** | Card com rota longa em 2 linhas | Melhor que antes; em telas estreitas ainda corta hash |
| **U8** | Sem deep-link estável `entityId` → detalhe da tx | Notificação abre home genérica |
| **U9** | Status “Na mempool / N/6” inconsistente entre home e detalhe em edge cases | Perda de confiança Electrum-like |
| **U10** | Insights double-count com payment links | Totais de período errados |

---

## 2. Princípios da próxima onda

1. **Uma projeção, zero merges paralelos** — extrato, insights, home, paged page0 = mesma lista.  
2. **Backend manda semântica; client só formata** — labels de rede/carteira/contraparte preferencialmente no DTO (ou display DTO), com fallback local.  
3. **Expor o útil, esconder o operacional** — usuário vê rede, carteira, valor, confs, memo; **não** vê quorum hash, refs internas, stack de falha.  
4. **Privacidade por camada** — lista compacta → detalhe expandido → copiar txid (ação consciente).  
5. **Reativo sem thrash** — um coordinator; merge por id em eventos; full pull só em cold start / pull manual.  
6. **Logout preserva; wipe é explícito** — sem mudar a política atual.

---

## 3. Exposição segura do que o backend já traz

### 3.1 Inventário `KfeTransactionResponse` → UI

| Campo BE | Uso seguro na UI | Expor como | **Não** fazer |
|----------|------------------|------------|----------------|
| `id` | PK estável, deep-link | Interno + “ID Kerosene” no detalhe (copiável) | Colapsar por txid |
| `status` | Status legível | Confirmado / Confirmando / Falhou / … | Mostrar enum cru SETTLED |
| `rail` | Rede | Interna / On-chain / Lightning | — |
| `direction` | Crédito/débito | Sinal do valor + Envio/Recebimento | — |
| `walletId` / source / dest | Sua carteira / De / Para | **Label** resolvido (nome), não UUID | UUID cru no card |
| amounts + fees | Valor, taxa rede, taxa serviço | Sats/BTC + fiat congelado | Somar fees duas vezes |
| `displayAmount*` / `displayBtc*` | Fiat histórico | Preferir sobre cotação live | Recalcular e mentir histórico |
| `provider` | Classificar cold/link/core | Mapear para badge (Cold, On-chain, …) | String `COLD_EXTERNAL_SPEND` no card |
| `providerReference` | Correlação interna | **Ocultar** (ou só build debug) | Mostrar no detalhe user-facing |
| `externalReference` | Endereço destino / ref | Hash compacto no card; full no detalhe + copy | Endereço completo no card se sensível em público |
| `memo` | Nota do user / produto | Linha “Nota” se não for placeholder de sistema | Deixar memo técnico sobrescrever título de ação |
| `blockchainTxid` | Explorer / confs | Compacto + copy + link explorer (testnet/mainnet) | Título principal = txid |
| `paymentHash` | LN | Detalhe LN only | Card principal |
| `confirmations` | Anel N/6 | Sempre verdade da API live | Fake 6/6 em SETTLED+0 |
| `failureCode` / `failureMessage` | Motivo de falha | Mapa de códigos → texto localizado; raw só se desconhecido e sanitizado | Stacktrace / paths de arquivo |
| `quorumProposalHash` / `quorumAckCount` | Ops interno | **Nunca** na UI consumer | — |
| `createdAt` / `updatedAt` | Quando + merge clock | Relativo + absoluto; **updatedAt no FE** | Usar só createdAt no merge |

### 3.2 Display DTO (recomendado, BE ou FE adapter)

Camada única de “presentation fields” (pode ser no FE primeiro):

```text
TransactionDisplay {
  actionTitle,          // "Recebimento cold"
  networkLabel,         // "Cold wallet (on-chain observada)"
  networkKind,          // enum
  ownWalletLabel,       // "Electrum Cold"
  fromLabel, toLabel,   // já resolvidos
  amountPrimary,        // fiat congelado ou BTC
  statusLabel,
  confirmationLabel,    // "2/6" | "Na mempool" | null se internal
  noteLabel?,           // memo se user-facing
  canCopyTxid, canOpenExplorer
}
```

**Regra:** card e detalhe **só** leem `TransactionDisplay`; raw `Transaction` fica no domain/storage.

### 3.3 Sanitização no BE (fase BE)

| Ação | Detalhe |
|------|---------|
| Strip consumer API | Não serializar `quorum*` no response mobile (ou profile `@JsonView`) |
| `failureMessage` allowlist | Mensagens genéricas por `failureCode`; detalhe só admin |
| Labels de contraparte | Opcional: `counterpartyLabel` / `walletLabel` resolvidos server-side no momento do evento |
| `provider` taxonomy | Enum estável documentado: `COLD_OBSERVE`, `COLD_SPEND`, `CUSTODIAL_ONCHAIN`, `INTERNAL_LEDGER`, `PAYMENT_LINK`, `LIGHTNING`, … |

---

## 4. Plano por fases (shippable)

### Fase P0 — Integridade e segurança mínima (3–5 dias)

**Meta:** extrato e insights contam a mesma história; confs não regredem; PIN gate.

| # | Tarefa | Critério de pronto |
|---|--------|--------------------|
| P0.1 | **Matar** `mergeInsightTransactions` legado | ✅ Insights usam **só** `transactionHistoryProvider` |
| P0.2 | Adicionar `updatedAt` em `Transaction` + parse de Instant | ✅ |
| P0.3 | Adapter merge: confs nunca descem | ✅ (LedgerMerge) |
| P0.4 | Datasource: 200 `[]` ≠ fallback statement cego | ✅ |
| P0.5 | Dedup payment link `pl_*` vs UUID KFE | ✅ |
| P0.6 | Auditar shell/PIN: não `watch` extrato antes do unlock | ✅ AppEntryPinGate no bootstrap; home só pós-unlock |
| P0.7 | Strip `quorum*` da UI / API consumer | ✅ Mapper BE null + FE não usa |

**Não fazer em P0:** SQLite, HMAC, redesign visual completo.

---

### Fase P1 — UX de clareza financeira (4–6 dias)

**Meta:** usuário nunca pergunta “de onde saiu esse saldo”.

| # | Tarefa | Critério de pronto |
|---|--------|--------------------|
| P1.1 | Introduzir `TransactionDisplay` (FE) centralizado | ✅ `transaction_display.dart` |
| P1.2 | Mapa `provider` → badge + ícone estável | ✅ via TransactionNetwork |
| P1.3 | Seção / chips de rede | ✅ filtros home + extrato |
| P1.4 | Detalhe: blocos movimento/rede/taxas | ✅ parcial (detalhe rico) |
| P1.5 | Falhas: `failureCode` → copy localizado | ✅ + Motivo no detalhe |
| P1.6 | Memo user vs sistema | ✅ noteLabel em TransactionDisplay |
| P1.7 | Cap 500: rodapé | ✅ barra de status N lançamentos |
| P1.8 | Deep-link notificação `entityId` | ✅ fetch by id + merge local |

---

### Fase P2 — Segurança e política de dados (2–4 dias)

| # | Tarefa | Critério de pronto |
|---|--------|--------------------|
| P2.1 | Setting **“Apagar extrato deste aparelho”** | ✅ Settings → Segurança |
| P2.2 | Documentar no Settings o que fica no device | ✅ copy no wipe |
| P2.3 | HMAC opcional do blob | ✅ HMAC-SHA256 + discard on tamper |
| P2.4 | `FLAG_SECURE` opcional | ✅ setting + FinancialSecureScope |
| P2.5 | CI: proibir `debugPrint` sensíveis | ✅ architecture guard + kDebugMode |
| P2.6 | Scope `user_{id}` preferencial | ✅ |

---

### Fase P3 — Sync reativo fino + BE display (1–2 semanas)

| # | Tarefa | Critério de pronto |
|---|--------|--------------------|
| P3.1 | Um único `refreshFinancialProjection` | ✅ financial_refresh.dart |
| P3.2 | WS/notif `entityId` → `GET /kfe/transactions/{id}` | ✅ notification_navigation |
| P3.3 | `GET /kfe/transactions?since=` | ✅ BE deployed + FE cursor |
| P3.4 | BE: labels wallet/counterparty | ✅ walletLabel / source / dest / counterpartyLabel |
| P3.5 | BE: taxonomy provider estável | ✅ normalizeProvider + FE taxonomy |
| P3.6 | Dirty flag + resume pull | ✅ financialDirtyProvider |
| P3.7 | Paged history alinhado | ✅ page 0 = transactionHistoryProvider |

---

### Fase P4 — Robustez

- SQLite projection se cap 500 / performance — ✅ `LocalTransactionSqlite` + seal HMAC  
- Explorer links por network (testnet/mainnet/regtest) — ✅ mempool.space  
- Export extrato (CSV/PDF) com redaction de endereços — ✅ CSV + PDF share  
- Telemetria: merge upgraded, statement fallback used, offline serve — ✅ contadores locais + Settings  
- A11y: anúncios VoiceOver de rede + valor + status — ✅ Semantics no card/detalhe  

**Estado:** plano de extrato considerado **fechado** para o escopo de produto atual. Dívida residual só se performance/SQLite ou PDF multi-idioma virarem prioridade.

---

## 5. Ordem de PRs sugerida

| PR | Conteúdo | Depende |
|----|----------|---------|
| **PR-X1** | Insights = history only; kill merge legado + testes | — |
| **PR-X2** | `updatedAt` + merge anti-regressão + empty-list datasource | — |
| **PR-X3** | Dedup payment-link vs KFE + failureCode no model | X2 |
| **PR-X4** | `TransactionDisplay` + card/detalhe unificados | X1 |
| **PR-X5** | Coordinator único + deep-link entityId | X2 |
| **PR-X6** | Settings wipe extrato + docs privacy | — |
| **PR-X7** | BE strip quorum + failure sanitization + provider taxonomy | paralelo |
| **PR-X8** | Incremental since + single-tx fetch | X5 + BE |

---

## 6. Critérios de qualidade (aceitação global)

### Segurança
- [ ] Logout **não** apaga extrato.  
- [ ] Wipe só com ação explícita confirmada.  
- [ ] User B nunca vê txs de user A no mesmo device.  
- [ ] Extrato não hidrata na tela de PIN.  
- [ ] Nenhum campo quorum / stack de falha na UI consumer.  
- [ ] Endereços longos só completos no detalhe ou após “mostrar”.

### Integridade
- [ ] Insights e home listam o **mesmo** conjunto de ids para o mesmo input.  
- [ ] Confs 0→N no cache local sobem após pull/WS; nunca descem.  
- [ ] Inbound + outbound com mesmo `blockchainTxid` = **2** linhas.  
- [ ] Payment link pago não duplica com linha KFE.

### UX
- [ ] Em qualquer tx o user responde: **qual carteira**, **de quem/para quem**, **qual rede**, **status**.  
- [ ] Link de pagamento distingue **interno** vs **on-chain**.  
- [ ] Cold nunca se mistura visualmente com on-chain custodial.  
- [ ] Pull e notificação atualizam saldo **e** extrato sem gesto extra.

### Exposição backend
- [ ] Matriz §3.1 implementada (mostrar / ocultar / mapear).  
- [ ] Fiat congelado preferido quando BE envia.  
- [ ] `updatedAt` usado no merge e opcionalmente “Atualizado …” no detalhe.

---

## 7. Testes mínimos a acrescentar

| Teste | Cobre |
|-------|-------|
| Insights ids == history ids | I1 |
| Local 0 conf + remote 6 → UI 6 | I2 |
| Cold spend + cold receive mesmo txid → 2 rows | merge |
| `pl_x` + KFE paid same ref → 1 row | S7 |
| Logout → reload app → extrato ainda no storage | política |
| Scope user A / user B isolados | S3 |
| `TransactionDisplay` payment link internal vs onchain | U1–U5 |
| failureCode LEDGER_* → copy localizado | U4 |

---

## 8. O que **não** fazer agora

- Reverter “logout preserva extrato”.  
- Big-bang SQLite antes de fechar P0/P1.  
- Mostrar UUID de wallet como “De/Para” na home.  
- Usar statement 24h como fonte de confs quando `/kfe/transactions` responde 200.  
- Logar payloads completos de tx em produção.

---

## 9. Resumo executivo

| Prioridade | Foco | Por quê |
|------------|------|---------|
| **Agora (P0)** | Unificar insights + `updatedAt` + dedup link + PIN gate | Inconsistências e double-count ainda mentem o extrato |
| **Em seguida (P1)** | `TransactionDisplay` + falhas legíveis + deep-link | UX de clareza que o user pediu |
| **Paralelo (P2/P3 BE)** | Strip campos ops, taxonomy provider, incremental | Segurança de exposição + sync fino |
| **Depois (P4)** | SQLite, export, telemetria | Escala e polish |

A base atual (rede + De/Para + local durable + reativo) é o **chão certo**. O maior gap residual **não** é visual: é **dois merges** (insights legado), **relógio de merge sem `updatedAt`**, **duplicatas de payment link**, e **campos de infra do BE ainda disponíveis no client** sem política de exposição.
