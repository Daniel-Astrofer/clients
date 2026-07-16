# Análise profunda — falhas, incoerências e UX do extrato

**Foco:** o que ainda **quebra a confiança** ou a **clareza** do usuário no dia a dia — não só segurança teórica.  
**Base:** código atual (LocalLedgerSync, classificação de rede, refresh reativo, logout preserva extrato).

---

## Como ler este doc

| Severidade | Significado para o user |
|------------|-------------------------|
| **P0** | “O app mentiu / sumiu com meu dinheiro na tela” |
| **P1** | Confunde origem/destino/rede ou some atividade recente |
| **P2** | Atrito, polish, acessibilidade, descoberta |
| **P3** | Nice-to-have / escala |

Cada item: **sintoma → causa no código → impacto → direção de correção**.

---

## A. Incoerências de “verdade” (saldo vs extrato vs insights)

### A1 — Lista remota vazia cai no statement de 24h **P0**

**Sintoma:** após limpar janela de statements ou conta nova com txs só no `transactions_master`, extrato pode mostrar **nada** ou payload **congelado/desatualizado**, enquanto o saldo está certo.

**Causa:**
```dart
// ledger_remote_datasource.getHistory
if (transactions.isNotEmpty) return transactions;
// empty 200 → cai no dashboard recentStatement
```

**Impacto:** user com saldo > 0 e extrato “vazio” ou confs presas; sensação de bug Electrum-like.

**Correção:** 200 + `[]` é resposta legítima. Fallback statement **só** em erro de rede / 5xx / timeout. Marcar `source` no merge.

---

### A2 — Só puxa **50** txs remotas; local guarda 500 **P0/P1**

**Sintoma:** txs antigas existem no local mas **não atualizam** confs/status se sumirem da page 0; txs 51–N no servidor nunca entram se o user não tiver puxado antes.

**Causa:** `getHistory(page: 0, size: 50)` único no `transactionHistoryProvider`.

**Impacto:** “sumiu a confirmação 6/6” em txs velhas; extrato “completo” no device é incompleto na API.

**Correção:** size 100–200 no cold start; `?since=` / paginar até esvaziar com cap; ou pelo menos re-pull ids locais ainda não SETTLED.

---

### A3 — Insights ainda mergeiam por `chain:txid` **P0**

**Sintoma:** totais do período / categorias **diferentes** da lista do extrato; inbound+outbound do mesmo txid vira **uma** linha nos insights.

**Causa:** `mergeInsightTransactions` em `statement_insights_provider.dart` (paralelo ao LocalLedgerSync).

**Impacto:** user desconfia dos gráficos e do “quanto gastei”.

**Correção:** insights = `transactionHistoryProvider` puro (sem segundo merge).

---

### A4 — Payment link `pl_*` + linha KFE = **duas** atividades **P0**

**Sintoma:** pagou um link e vê “Link de pagamento” **e** “Recebimento on-chain” com o mesmo valor/txid.

**Causa:** `_mergeExternalHistory` une KFE + `paymentLinks.map(toTransaction)` por id diferente (`pl_$id` vs UUID).

**Impacto:** double-count visual e em insights; “paguei duas vezes?”.

**Correção:** dedup por `blockchainTxid` / `settlementReference` / provider PAYMENT_LINK; preferir linha KFE liquidada e manter link só se ainda pending.

---

### A5 — Saldo atualiza na hora; extrato depende de invalidate+full pull **P1**

**Sintoma:** WS de balance muda o cartão; a lista ainda mostra o estado antigo por 1–30s (ou até o poll).

**Causa:** balance path aplica delta em memória; history path invalida FutureProvider (async). Há `refreshFinancialProjection`, mas ainda há caminhos que só mexem em wallet.

**Impacto:** “o saldo subiu e não tem lançamento”.

**Correção:** optimistic row (pending) no local no send/receive detect; single-tx fetch por `entityId`; skeleton com **previous data** (não blank loading).

---

### A6 — `updatedAt` do BE não vive no `Transaction` FE **P1**

**Sintoma:** merge usa `timestamp` ≈ createdAt; confs/status novos podem perder para payload local “completo” se relógio empatar mal.

**Causa:** adapter `updatedAt: updatedAt ?? tx.timestamp`.

**Impacto:** conf “grudada” em 0 após restart; race local vs remote.

**Correção:** campo `updatedAt` real + regras anti-regressão de confs (já parcialmente no LedgerMerge).

---

## B. Classificação e filtros — UX quebrada entre telas

### B1 — Home e Extrato usam **filtros diferentes** **P1**

| Home | Extrato (statement) |
|------|---------------------|
| all, in, out, **internal, onchain, cold**, pending, failed, cancelled | all, in, out, pending, failed, **onchain, lightning, internal** (sem cold, sem cancelled) |

**Sintoma:** user filtra “Cold” na home; no extrato completo “some” o filtro. On-chain no extrato **inclui cold** (`!lightning && !internal`).

**Impacto:** sensação de app inconsistente; cold misturado com custodial no extrato.

**Correção:** um enum de filtro compartilhado + mesma classificação `TransactionNetwork`.

---

### B2 — “On-chain” no extrato = cold + hot **P1**

**Sintoma:** filtro On-chain lista Electrum e Money juntos.

**Causa:** statement `_StatementFilter.onchain` não usa `resolveTransactionNetwork`.

**Correção:** onchain = só plataforma; cold = separado (como na home).

---

### B3 — Canceladas / expiradas **P1**

**Home:** canceladas só no chip “Canceladas”; sumidas do “Tudo”.  
**Extrato:** filtro “Todos” **inclui** canceladas (não há filtro cancelled).  
**Failed:** home inclui `isUnconfirmedExpired`; extrato failed **só** `status == failed` (não-confirmada 24h pode não aparecer em Failed).

**Impacto:** “sumiu a tx” vs “ainda está no extrato”; 24h unconfirmed órfã de filtro.

**Correção:** alinhar regras de visibilidade; failed ⊃ unconfirmed expired em ambas.

---

### B4 — Busca do extrato não busca **nome de carteira** **P2**

**Sintoma:** digita “Electrum” e não acha; UUID de wallet no searchText mas não o label resolvido.

**Causa:** `_searchText` junta ids brutos, não `resolveWalletDisplayName` / route summary.

**Correção:** indexar labels resolvidos + network label + status legível.

---

### B5 — Filtro por “carteira ativa” **não existe** **P1**

**Sintoma:** user com Money + Cold vê **tudo misturado** no feed; troca o card de saldo mas o extrato não segue a carteira.

**Causa:** home lista projeção global; `transactionsByWalletProvider` filtra por **address string**, não por `walletId`.

**Impacto:** “de onde saiu esse saldo” piora com multi-wallet.

**Correção:** filtro “desta carteira” (walletId / source / dest) + opcional “todas”; sincronizar com card selecionado (setting).

---

## C. Loading, offline e estados vazios

### C1 — Invalidate → flash de loading no feed **P1**

**Sintoma:** a cada notificação/WS a lista some e volta “Carregando…” (em `when(loading:)`).

**Causa:** `FutureProvider` sem keep previous; home mitiga saldo com `asData` mas a lista de txs usa `when` completo.

**Impacto:** sensação de app instável; scroll position lost.

**Correção:** `AsyncValue` com previous value / `skipLoadingOnReload` pattern; skeleton only first load.

---

### C2 — Offline sem banner no extrato **P1**

**Sintoma:** rede cai; lista local aparece como se fosse “live”; confs param e user não sabe por quê.

**Causa:** offline serve local silenciosamente; send tem banner, home extrato não.

**Impacto:** desconfiança (“confirmação não sobe”).

**Correção:** chip “Offline · extrato local” + hora do último sync.

---

### C3 — Empty state enganoso com saldo **P1**

**Sintoma:** saldo > 0 + lista vazia (por A1, filtro, ou cancel-only) mostra “sem transações / deposite”.

**Causa:** empty panel não distingue: sem dados | filtro vazio | só canceladas | offline vazio.

**Correção:** copy contextual: “Nada neste filtro”, “Aguardando sincronizar”, “Saldo existe mas histórico remoto vazio — puxe para atualizar”.

---

### C4 — Erro de rede com local = **não mostra erro** (às vezes bom, às vezes ruim) **P2**

**Sintoma:** falha de API + local antigo: UI “ok” sem avisar que pode estar defasado.

**Correção:** soft warning, não full error se local existe.

---

### C5 — First-use panel quando tem saldo e “sem txs” **P2**

**Sintoma:** user recebeu cold observed, saldo subiu, history ainda vazio por race → painel first-use “deposite” aparece.

**Causa:** home `!hasTransactions && hasBalance` ativa first-use.

**Correção:** não ativar first-use se `hasBalance` ou se refresh ainda in-flight.

---

## D. De / Para / rede — clareza residual

### D1 — UUID de wallet no from/to se lista de wallets não carregou **P1**

**Sintoma:** “De: a0c25fd0-…” no card.

**Causa:** `resolveWalletDisplayName` falha sem wallets/accounts; fromAddress pode ser o id cru do KFE.

**Correção:** nunca mostrar UUID no card (placeholder “Carteira”); detalhe pode mostrar id técnico recolhido; cache de labels no local row.

---

### D2 — Contraparte interna sem username no BE **P1**

**Sintoma:** envio interno “Para: Carteira Kerosene” genérico.

**Causa:** `KfeTransactionResponse` sem `senderDisplayName` / `receiverDisplayName` / username.

**Correção:** BE incluir label de contraparte quando for INTERNAL; FE gravar no local.

---

### D3 — Rota longa no card (2 linhas) ainda corta **P2**

**Sintoma:** “De X → Y · Cold wallet (on-chain observada)” elide o essencial.

**Correção:** card compacto em 2 linhas fixas:
1. `De → Para` (sem rede)
2. Badge rede + status (pill)

---

### D4 — Payment link “pending” polui extrato operacional **P2**

**Sintoma:** dezenas de links abertos/expirados no meio de movimentos reais.

**Causa:** todos `toTransaction()` entram no merge.

**Correção:** separar “Pedidos / links” de “Movimentações”; ou só links paid/validating no feed principal; pending em aba própria.

---

### D5 — Cold inbound: externalReference é **nosso** endereço **P2**

**Sintoma:** se UI errar e mostrar externalReference como “De”, user vê o próprio endereço como origem.

**Causa:** KFE guarda receive address em externalReference no inbound cold; FE já tenta não usar isso no credit — regressões fáceis.

**Correção:** testes de ouro por provider; documentar contrato BE.

---

### D6 — Fee: gross vs receiver vs totalDebit **P1**

**Sintoma:** valor no card ≠ o que saiu do saldo (fee de rede/serviço).

**Causa:** FE usa `receiverAmountSats` como amount; totalDebit pode ser maior; card não mostra “total debitado” no compacto.

**Correção:** débito compacto = total saído (amount+fees quando isDebit); detalhe quebra amount + taxa rede + taxa serviço.

---

## E. Notificações e deep-link

### E1 — Notificação com metadata incompleta abre detalhe “fake” **P1**

**Sintoma:** toca notificação → tela de detalhe com campos “—” / valor errado / sem rede.

**Causa:** `_transactionFromNotificationMetadata` sintetiza Transaction mínima se não achar no history.

**Impacto:** pior que abrir o extrato.

**Correção:** se não achar, pull by id; se falhar, abrir extrato destacado, **não** detalhe incompleto.

---

### E2 — Notificação some ao matar o app **P2**

**Sintoma:** inbox de sessão zera; histórico de alertas some.

**Causa:** `sessionNotificationFeedProvider` em memória.

**Correção:** persistir últimas N notificações (sem payload sensível excessivo) ou “só no extrato”.

---

### E3 — Copy de notificação ≠ card do extrato **P2**

**Sintoma:** notificação “Transferência Onchain” vs card “Recebimento cold”.

**Causa:** heurística de rede no WS provider independente de `resolveTransactionNetwork`.

**Correção:** mesma taxonomia de rede em notificação e extrato.

---

## F. Multi-wallet e multi-user

### F1 — Extrato global sem “contexto da carteira selecionada” **P1**

Já em B5. Reforço: saldo do carrossel é por wallet; extrato é global → dissonância cognitiva forte.

---

### F2 — Scope de storage **P2**

Se `sessionStorageScope` degradar para username, colisão entre contas.

**Correção:** assert `user_{id}` numérico; teste troca de conta.

---

### F3 — Logout preserva extrato; segundo user no device **P2**

OK se scope correto; falta onboarding “outro usuário neste aparelho: extratos ficam separados”.

---

## G. Performance e percepção

### G1 — Full pull + links + external transfers em série a cada invalidate **P1**

**Sintoma:** Tor lento → lista demora; várias invalidates empilham.

**Causa:** history provider sempre: getHistory + external + paymentLinks + merge + save.

**Correção:** debounce coordinator; cache curto de links; single-tx path.

---

### G2 — Secure storage JSON 500 txs a cada merge **P2**

**Sintoma:** jank ao salvar em devices fracos.

**Correção:** write debounce; SQLite depois se necessário.

---

### G3 — Anéis de conf animados em dezenas de cards **P2**

**Sintoma:** scroll pesado com muitas mempool.

**Correção:** animar só expanded / só primeiras N pending.

---

## H. Acessibilidade, i18n, privacidade no uso

### H1 — Filtros “Interna / On-chain / Cold” hardcoded PT **P2**

**Causa:** home filter labels sem l10n.

**Impacto:** EN/ES quebrado.

---

### H2 — Detalhe e cards: strings PT fixas (“Sua carteira”, “Na mempool”) **P2**

Mesmo problema em vários caminhos.

---

### H3 — Sem modo “ocultar valores” no extrato **P2**

User esconde saldo no card mas extrato ainda mostra valores em claro.

---

### H4 — Task switcher / screenshot **P3**

Valores e endereços no recents do OS.

---

### H5 — Copy/paste de txid sem feedback de “compartilhar com cuidado” **P3**

---

## I. Fluxos de produto que o extrato não explica

| Fluxo | Falha de UX |
|-------|-------------|
| Cold → custodial (deposit credit) | Pode parecer “apareceu dinheiro” se só uma perna da história estiver no feed |
| Envio cold (PSBT) | Antes do broadcast: gap entre “assinei” e linha no extrato |
| Link interno vs on-chain | Melhorou nos labels; pending links ainda poluem |
| Taxa de serviço Kerosene | Só no expand; user acha que “faltou sats” |
| Swap / fee type | Raros; visual genérico |
| Internal memo sempre `"transfer"` no send | Memo inútil no BE (hardcoded) → sem nota real |

---

## J. Matriz priorizada (nova passagem)

### P0 — confiar no número

1. Empty `/kfe/transactions` ≠ fallback statement cego  
2. Matar merge legado de insights  
3. Dedup payment link vs KFE  
4. Page size / re-sync de txs abertas além do top 50  
5. Anti-regressão confs + `updatedAt`  

### P1 — entender o movimento

6. Filtros unificados home ↔ extrato (cold ≠ onchain)  
7. Filtro “carteira selecionada”  
8. Loading sem apagar lista (keep previous)  
9. Banner offline + last sync  
10. Empty states honestos  
11. Debito mostra total saído (fees)  
12. Notificação → não abrir detalhe fake  
13. Labels de contraparte (BE ou cache)  
14. Coordinator único (fim dos invalidates soltos)  

### P2 — experiência polida

15. Separar “Links/pedidos” de “Movimentos”  
16. Busca por nome de carteira/rede  
17. l10n de filtros e status  
18. Ocultar valores no extrato se saldo oculto  
19. Copy de notificação = taxonomia do extrato  
20. Debounce save / pull  

### P3 — escala e privacidade extra

21. HMAC blob, FLAG_SECURE, SQLite, export, explorer links  

---

## K. Melhorias de UX de alto ROI (mesmo sem BE)

| Melhoria | Esforço | Efeito |
|----------|---------|--------|
| Keep previous data no history provider | Baixo | App “para de piscar” |
| Banner offline + lastSync | Baixo | Confiança |
| Unificar filtros + cold no extrato | Baixo | Consistência |
| Dedup pl_* | Médio | Fim do double-count |
| Filtro por wallet selecionada | Médio | “Esse saldo” tem extrato |
| Card: linha1 De→Para, linha2 badge rede | Baixo | Legibilidade |
| Empty/filter copy contextual | Baixo | Menos “sumiu tudo” |
| Insights = history only | Baixo | Totais corretos |
| Não sintetizar detalhe fraco da notificação | Baixo | Menos tela quebrada |
| Rodapé “N lançamentos locais · atualizado HH:mm” | Baixo | Transparência |

---

## L. Checklist mental do user (aceitação)

O user satisfeito responde **sim** a:

1. O saldo mudou → **em poucos segundos** vejo o lançamento (ou “sincronizando…”).  
2. Sei **qual carteira** foi afetada.  
3. Sei se foi **interno / cold / on-chain / link**.  
4. Sei **para quem / de quem** (ou endereço curto, não UUID).  
5. Confs sobem **sem sumir e voltar** a lista.  
6. Insights batem com a lista.  
7. Offline: sei que é cache, não “live”.  
8. Multi-wallet: posso ver **só essa carteira**.  
9. Não vejo o mesmo pagamento **duas vezes**.  
10. Notificação abre **a mesma** tx do extrato (ou o extrato, não um fantasma).

Hoje o app está **bom em 2–4 e  parcialmente 5**; **1, 5–10** ainda falham em edge cases reais.

---

## M. Relação com o plano anterior

| Doc | Papel |
|-----|--------|
| `TRANSACTION_HISTORY_IMPROVEMENT_PLAN.md` | Roadmap de implementação (P0–P4, PRs, exposição BE) |
| **Este doc** | Diagnóstico de **uso real**: falhas de percepção, multi-tela, empty/offline, notificação, multi-wallet |

**Próximo incremento sugerido (ordem de dor do user):**

1. A1 + A3 + A4 (verdade do extrato)  
2. C1 + C2 + C3 (estados)  
3. B1 + B2 + B5 (filtros e carteira)  
4. E1 + A5 (notificação e reatividade fina)
