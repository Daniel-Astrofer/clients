# Análise ampla: histórico e armazenamento de transações no app

**Escopo:** Flutter FE (Kerosene) + pontos de contato com KFE/server.  
**Data de referência:** estado do código após LocalLedgerSync PR1–PR4.

---

## 1. Visão geral em uma frase

O extrato do app é uma **projeção híbrida**: tenta o remoto (`/kfe/transactions` ou fallback do dashboard), mescla com extras (payment links / external transfers), **persiste no secure storage por usuário**, e a UI lê o resultado; offline, serve só o local se existir.

```
┌─────────────┐   ┌──────────────────┐   ┌─────────────────────┐
│  KFE remoto │   │  Extras remotos  │   │ Secure storage      │
│  txs + dash │   │  links / external│   │ tx_history_v1:user_ │
└──────┬──────┘   └────────┬─────────┘   └──────────▲──────────┘
       │                   │                         │
       └─────────┬─────────┘                         │
                 ▼                                   │
        merge em memória  ── LocalLedgerSync ────────┘
                 │
                 ▼
        transactionHistoryProvider
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
      Home    Extrato   Insights*
```

\*Insights ainda tem merge **paralelo e mais fraco** (ver §8).

---

## 2. O que é armazenado (e onde)

### 2.1 No dispositivo (durável)

| O quê | Onde | Chave | Formato | Limite |
|-------|------|-------|---------|--------|
| Histórico de txs | `LocalTransactionHistoryStore` | `tx_history_v1:{sessionScope}` | JSON lista de `Transaction.toJson()` | **500** mais recentes |
| Escopo de sessão | derivado do auth | `user_{id}` ou `username_{name}` | string sanitizada | — |
| Preferências (alertas, ocultar saldo, etc.) | SharedPreferences / secure | chaves próprias | bool/int | — |
| Notificações de sessão | em memória (`sessionNotificationFeedProvider`) | — | lista | volta a zero ao reiniciar app |

**Secure storage** = Keychain / EncryptedSharedPreferences via `SecureStorageService`.

**Não** é SQLite. Não há cursor de sync nem versionamento de blob.

### 2.2 Campos de cada `Transaction` no local

Serializado via `toJson()` / `fromJson()`:

- Identidade: `id`, `blockchainTxid`, `paymentHash`, `invoiceId`, `externalTransferId`
- Partes: `fromAddress`, `toAddress`, wallet ids, display names
- Valores: `amountSatoshis`, `feeSatoshis`, `serviceFeeSatoshis`
- Estado: `status`, `type`, `confirmations`, `timestamp`
- Flags: `isInternal`, `isLightning`, `hasNetworkFee`
- Fiat congelado opcional: `displayAmountUsd/Eur/Brl`, cotações BTC
- Meta: `description`, `externalReference`, lightning invoice, etc.

**Não grava explicitamente** `updatedAt` de servidor — o merge usa `timestamp` como relógio.

### 2.3 No servidor (KFE) — o que o app **consome**

| Fonte | Endpoint / mecanismo | Conteúdo | Retenção típica |
|-------|----------------------|----------|-----------------|
| **Lista de txs** | `GET /kfe/transactions?page&size` | `KfeTransactionResponse` (id, status, confs, amounts, wallets, Instant created/updated) | DB `transactions_master` (longo prazo) |
| **Dashboard** | `GET` dashboard KFE | wallets + `recentStatement` | Statements **~24h** (`expiresAt`) |
| **Statement item** | embutido no dashboard | `displayPayloadJson` **congelado** na criação (+ refresh parcial de confs no BE) | 24h |
| **Payment links** | API de links | convertidos em `Transaction` sintéticas | conforme produto |
| **External transfers** | API própria | convertidos em `Transaction` | conforme produto |
| **WS saldo/notif** | STOMP | não grava histórico; **invalida** providers | efêmero |

---

## 3. O que o app **expõe** (UI / providers)

| Superfície | Provider / fonte | O que mostra |
|------------|------------------|--------------|
| Home (lista recente) | `transactionHistoryProvider` | Lista mergeada local+remoto |
| Extrato / statement screen | mesmo provider (+ filtros) | Histórico completo da projeção |
| Filtros Enviadas/Recebidas | `filteredTransactionsProvider` | Subconjunto por `type` |
| Por endereço | `transactionsByWalletProvider` | match from/to string |
| Depósitos | `depositsProvider` | subset receive/deposit do histórico |
| Insights do extrato | `statementInsightsReportProvider` | **remote + local com merge próprio** (§8) |
| Detalhe da tx | tela de detalhe com um `Transaction` | campos da entidade (confs, de/para, quando relativo) |
| Saldos home/contas | `walletProvider` / `BitcoinAccount` | cold=`observed`, custodial=`available` (+ subtítulo “Na rede”) |

---

## 4. Pipeline de leitura (online)

```
1. sessionStorageScopeProvider
   └─ null se não autenticado → histórico vazio

2. localStore.load(scope)
   └─ lista local (pode estar vazia)

3. ledgerRepo.getHistory(page:0, size:50)
   ├─ tenta GET /kfe/transactions
   │    └─ se lista não vazia → usa como raw
   └─ senão / erro → GET dashboard → recentStatement (payload JSON)

4. Transaction.fromJson em cada item
   └─ normaliza status, confs, timestamps (UTC bare → local)

5. + getExternalTransfers() e getPaymentLinks() (falha silenciosa → [])

6. _mergeExternalHistory(KFE + extras)
   └─ TransactionLedgerAdapter.mergeTransactionLists

7. LocalLedgerSync.hydrateAndMerge(local, remote)
   ├─ merge field-level (id, confs, status, amounts)
   ├─ save secure storage (cap 500)
   └─ retorna projeção para a UI
```

### Preferência de fonte remota

1. **`/kfe/transactions`** — autoridade (confs ao vivo)  
2. **Dashboard statements** — só se a lista de txs vier vazia ou a chamada falhar  

Statements com confs “congeladas” **não deveriam** vencer a API de txs quando ambas existem (porque a API é tentada primeiro). Se só houver statement (API vazia/erro), confs podem ficar defasadas até o BE refresh ou nova tx list.

---

## 5. Regras de merge (LocalLedgerSync)

### Chave de identidade

1. **`id` (UUID KFE)** → `id:{uuid}`  
2. Senão `blockchainTxid` + direção (`out`/`in`)  
3. Senão `unknown`

Assim **inbound e outbound com o mesmo txid on-chain não colapsam**.

### Campos em conflito (mesmo id)

| Campo | Comportamento |
|-------|----------------|
| `confirmations` | Remoto **mais novo** manda; remoto **mais velho** não regride confs locais |
| `status` | Idem; statement fraco não rebaixa status se local já tem confs |
| amounts / fees | Remoto se mais novo |
| `createdAt` | o mais antigo dos dois (estável) |
| Linha só local | permanece se o remoto não a trouxer |

Cap: **500** entradas, ordenadas por `timestamp` desc.

---

## 6. Eventos: o que acontece

### 6.1 Login / sessão autenticada

- `sessionStorageScopeProvider` = `user_{id}`  
- Home / loading **invalida** `transactionHistoryProvider`  
- Primeiro `watch` dispara o pipeline §4  
- Se já houver blob local do mesmo user → merge com remoto  

### 6.2 Logout

- Auth limpa token/sessão  
- Scope vira `null` → providers de histórico devolvem **lista vazia** na UI  
- **O secure storage do extrato NÃO é apagado** no logout  
- Próximo login do **mesmo** user reutiliza o histórico local  

(Limpar dados do app / desinstalar sim apaga.)

### 6.3 Pull-to-refresh / invalidate

- Home e extrato chamam `ref.invalidate` / `refresh(transactionHistoryProvider)`  
- Refaz o pipeline completo (rede + merge + persist)

### 6.4 Após envio / pagamento / withdraw com sucesso

- Vários fluxos em `transaction_provider` invalidam o histórico  
- Próximo rebuild puxa de novo (não há “append otimista” universal no store)

### 6.5 Notificação WebSocket (saldo/tx)

- `balance_websocket_provider` ao receber notificação financeira:  
  - `invalidate(transactionHistoryProvider)`  
  - `invalidate(pagedTransactionHistoryProvider)`  
  - `walletProvider.refresh()`  
  - notificação nativa (se preferências ok)  
- **Não** grava a tx no local só pelo payload da notificação; depende do pull seguinte  

### 6.6 Atualização de saldo WS

- Atualiza `Wallet.balance` (+ `observedSats` ou `availableSats` conforme cold/custodial)  
- **Não** altera o extrato local por si só  

### 6.7 Background service (app fechado, Android)

- Poll REST de notificações / WS se clearnet  
- Mostra alertas nativos  
- **Não** atualiza o extrato local em disco no isolate de background (só ao reabrir e invalidar/pull)

### 6.8 Paginação (`pagedTransactionHistoryProvider`)

- Page 0: merge com links/external **em memória**  
- Page > 0: só remoto  
- **Não** grava páginas extras no secure storage  
- UI principal de extrato usa o provider **não paginado** (page 0 size 50 + local)

---

## 7. Conectado vs desconectado

| Situação | Histórico | Saldos | Notificações |
|----------|-----------|--------|--------------|
| **Online, auth ok** | Pull + merge + save; UI = projeção | Dashboard/wallets + WS | WS + push local |
| **Online, `/kfe/transactions` falha, dashboard ok** | Fallback statements (payload pode estar desatualizado) + merge local | Dashboard | WS se conectado |
| **Offline, tem cache local** | Serve **só local** (sem throw) | Último estado em memória se já carregou; senão erro/vazio | Sem novas |
| **Offline, sem cache** | Erro / empty dependendo da tela | Erro ou zero | Nada |
| **Sem auth** | `[]` | sem dados de user | — |

### Diagrama de estados efetivos

```
        [sem auth]
            │
            ▼
      histórico = []
            │ login
            ▼
      ┌─ hydrating ─┐
      │ load local  │
      │ pull remote │── fail + local empty ──► erro UI
      │ merge+save  │── fail + local ok ────► offline UI (local)
      └──────┬──────┘
             │ ok
             ▼
           live ◄──── invalidate / WS / pull-to-refresh
             │
             │ rede cai
             ▼
         offline (mostra local se existir)
```

Não há máquina de estados formal no código; o comportamento emerge de `FutureProvider` + fold de `Either`.

---

## 8. Inconsistências e armadilhas conhecidas

| # | Problema | Impacto |
|---|----------|---------|
| 1 | **`statementInsightsProvider`** ainda mergeia por `chain:txid` e score fraco | Insights podem colapsar inbound+outbound e ignorar confs |
| 2 | **Paged history** não passa por `LocalLedgerSync` | Página 0 “insights” pode divergir do extrato principal se usado |
| 3 | **Sem `updatedAt` na entidade `Transaction`** | Merge usa `timestamp`; conf touch no BE pode não reordenar o “relógio” se createdAt fixo |
| 4 | **Statement 24h no servidor** | Sem local + sem lista de txs, extrato “some” após janela |
| 5 | **Logout não limpa extrato local** | Intencional (continuidade), mas multi-user no mesmo device depende do scope |
| 6 | **Background não grava extrato** | App fechado: alertas sim, projeção só ao reabrir |
| 7 | **Cap 500** | Txs antigas caem do dispositivo (servidor ainda tem se lista de txs for completa) |
| 8 | **Duas “verdades” de confs** | API txs vs statement JSON; prioridade de fetch mitiga, não elimina |

---

## 9. Backend (resumo do que o app enxerga)

| Camada KFE | Papel |
|------------|--------|
| `transactions_master` | Fonte canônica de txs (confs atualizáveis) |
| `user_statements` | Feed curto com JSON de display; `refreshTransactionDisplayPayload` tenta atualizar confs |
| Observadores cold/custodial | Criam linhas + notificam; confs sobem via monitor / observe |
| Dashboard | Wallets + top 25 statements não expirados |

O app **não** replica o schema do KFE; só um JSON de projeção de UI.

---

## 10. Mapa “evento → storage → UI”

| Evento | Escreve secure storage? | Atualiza UI histórico? | Atualiza saldo? |
|--------|-------------------------|------------------------|-----------------|
| Pull history sucesso | Sim (merge) | Sim | Não (outro path) |
| Pull history falha + local | Não | Sim (local) | Não |
| Notificação WS | Indireto (invalidate → pull) | Sim se pull ok | Sim (refresh wallet) |
| Balance WS | Não (só Wallet em memória) | Não | Sim |
| Envio sucesso | Indireto (invalidate) | Sim após pull | Sim se refresh |
| Logout | Não | Esvazia via scope | Esvazia |
| Clear app data | Sim (apagado pelo SO) | Vazio até login+pull | Vazio |

---

## 11. Conclusão da análise

### O que está coerente

- Escopo por usuário no storage  
- Persistência cifrada do extrato além da janela 24h do statement  
- Preferência por `/kfe/transactions` quando disponível  
- Merge por **id** + confs (LocalLedgerSync) no caminho principal  
- Offline graceful se já houve sync  

### O que ainda é “sistema híbrido”

- Três origens remotas (txs API, statement, extras)  
- Insights com merge **legado** paralelo  
- Paginação sem projeção local  
- Sync por **invalidate + full pull**, não por evento idempotente por id  
- Relógio de merge baseado em `timestamp` da tx, não `updatedAt` de servidor  

### Resposta prática

| Pergunta | Resposta |
|----------|----------|
| O app armazena histórico local? | **Sim**, até 500 txs por user no secure storage |
| Precisa de rede para ver extrato? | **Não**, se já sincronizou antes |
| O local é a verdade absoluta? | **Não** — remoto manda em confs/status no merge; local **completa** o que o servidor esqueceu |
| Limpar dados do app? | Só se ainda houver lixo de chaves antigas; com merge novo, refresh costuma bastar |
| Está “bem arquitetado”? | **Base correta em evolução**; ainda há caminhos paralelos (insights, paged) e falta de `updatedAt` formal |

---

## 12. Próximos passos recomendados (opcional)

1. Unificar `mergeInsightTransactions` com `TransactionLedgerAdapter` / `LedgerMerge`.  
2. Fazer paged history também passar por `LocalLedgerSync` (ou descontinuar paged se não for usado).  
3. Propagar `updatedAt` da API para a entidade `Transaction`.  
4. Em logout opcional: política explícita “manter extrato” vs “apagar ao sair”.  
5. Evento WS `entityId` → fetch de **uma** tx e merge por id (menos full pull).
