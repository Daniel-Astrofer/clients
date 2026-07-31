# Content Language

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

Tokens define visual consistency. Content language defines verbal consistency. When every screen uses the same terminology, tone, and patterns, the product feels coherent even across features built by different agents.

---

## 1. Voice

Kerosene's voice is:
- **Precise** — say exactly what happened, with exact numbers
- **Calm** — financial information is factual, never sensational
- **Direct** — verb-first labels, no filler words
- **Technically accurate** — correct blockchain/custody terminology without jargon

### Tone by context

| Context | Tone | Example |
|---------|------|---------|
| Financial data | Serious, clear | "Saldo: R$ 1.500,00" not "Voce tem R$ 1.500,00!" |
| Onboarding | Warm, educational | "Sua carteira foi criada" not "Parabens! Carteira criada com sucesso!" |
| Error | Direct, actionable | "Saldo insuficiente. Voce tem R$ 100,00 disponiveis." not "Erro!" |
| Success | Brief, confirming | "Enviado: R$ 50,00 para Maria" not "Transacao completada com sucesso!" |
| Processing | Reassuring, status | "Processando..." with estimated time |

---

## 2. Terminology

### Canonical terms (pt-BR)

| Term | Usage | Never use |
|------|-------|-----------|
| Saldo | Total available funds | "Fundos", "Dinheiro", "Total" |
| Enviar | Outgoing transaction | "Transferir", "Pagar", "Mandar" |
| Receber | Incoming transaction | "Depositar", "Cobrar" |
| Movimentacao | Transaction record | "Transacao" (use only for on-chain context) |
| Carteira | Wallet | "Conta", "Account" |
| Custodia | Custody type | "Tipo de conta", "Guardia" |
| Rede | Network (Lightning, on-chain) | "Blockchain", "Chain" |
| Taxa | Fee | "Custo", "Tarifa", "Comissao" |
| Confirmacao | Block confirmation | "Validacao", "Aprovacao" |
| Chave | Cryptographic key | "Senha" (PIN is senha, key is chave) |
| Endereco | Bitcoin address | "Codigo", "Chave publica" |
| Fatura | Lightning invoice | "Invoice", "Boleto" |

### Abbreviations
- **BTC**: always uppercase, with space before ("0.001 BTC")
- **sats**: lowercase, with space before ("500 sats")
- **R$**: Brazilian real, with space before amount ("R$ 1.500,00")
- **USD**: with space before amount when mixed ("~USD 100")

---

## 3. Button labels

### Rules
- Verb-first: "Enviar", not "Envio" or "Confirmar envio"
- Max 3 words in pt-BR
- Never "Clique aqui", "OK", "Sim/Nao"
- Primary action describes the outcome: "Enviar R$ 50,00" is better than "Confirmar"

### Standard labels

| Action | Label |
|--------|-------|
| Send money | "Enviar" |
| Confirm send | "Enviar R$ {valor}" |
| Receive money | "Receber" |
| Cancel | "Cancelar" |
| Go back | "Voltar" |
| Retry | "Tentar novamente" |
| Close | "Fechar" |
| Copy address | "Copiar endereco" |
| Share | "Compartilhar" |
| Save | "Salvar" |
| Delete/Remove | "Remover" (with confirmation) |

---

## 4. Number formatting

### Brazilian locale (pt-BR)
- Decimal separator: comma (R$ 1.500,00)
- Thousands separator: dot (R$ 1.500,00)
- BTC: period decimal, space thousands (0.00150000 BTC)
- sats: integer, space thousands when >9999 (10 000 sats)

### Precision
- Fiat (BRL): 2 decimal places (R$ 1.500,00)
- BTC: 8 decimal places (0.00150000 BTC), trim trailing zeros to min 2
- sats: integer, no decimal

### Alignment
- Financial numbers in lists: decimal-aligned (use tabular figures)
- Balance hero: centered or left-aligned with label
- Transaction rows: right-aligned amount column

---

## 5. State messages

### Loading states
- "Carregando..." (generic loading)
- "Conectando..." (network/connection)
- "Sincronizando..." (blockchain sync)
- "Processando pagamento..." (payment in flight)
- "Autorizando..." (PIN/passkey)

### Error states — format
```
[What happened]
[Why it happened]
[What to do]

Example:
Saldo insuficiente
Voce tem R$ 100,00 disponiveis. O envio requer R$ 150,00.
[Depositar] [Alterar valor]
```

### Empty states — format
```
[What belongs here]
[Why it's empty]
[Action to fill it]

Example:
Nenhuma movimentacao
Quando voce enviar ou receber, suas movimentacoes aparecem aqui.
[Fazer primeiro envio]
```

### Success states
- "Enviado: R$ 50,00 para Maria" (with tx detail link)
- "Recebido: 0.001 BTC de Joao"
- "Carteira criada"

---

## 6. Sensitive contexts

### Security language
- Never use fear words: "risco", "perigo", "ameaca", "urgente"
- PIN is "PIN" or "codigo de acesso", never "senha" (password is different)
- Recovery is "recuperacao", never "emergencia"
- Security settings are factual: "Autenticacao de dois fatores", not "Proteja sua conta!"

### Custody language
- Cold wallet: "Carteira fria (controle total)" — emphasizes control, not danger
- Hot custody: "Custodia Kerosene" — neutral, factual
- Lightning: "Lightning (instantaneo)" — emphasizes benefit
- On-chain: "On-chain (seguro)" — emphasizes benefit

---

## Token & file map

| Concept | Source file |
|---------|------------|
| ARB translations (pt-BR) | `lib/core/l10n/app_pt.arb` |
| L10n extension | `lib/core/l10n/l10n_extension.dart` |
| Money display formatting | `lib/core/utils/money_display.dart` |
| QR payment parser | `lib/core/utils/qr_payment_parser.dart` |

---

## Do / Don't

- [ ] DO use canonical terminology consistently
- [ ] DO format error messages as what/why/action
- [ ] DO use verb-first button labels, max 3 words
- [ ] DO format numbers with Brazilian locale for fiat, standard for BTC
- [ ] DO keep security language factual, never fear-based
- [ ] DON'T use "Sucesso!", "Parabens!", or exclamation marks
- [ ] DON'T use "Erro!" without explanation
- [ ] DON'T use "Clique aqui", "OK", "Sim/Nao" as button labels
- [ ] DON'T mix Portuguese and English terms
- [ ] DON'T use fear language in security contexts

---

## Verification

- [ ] All button labels are verb-first, ≤3 words?
- [ ] All error messages follow what/why/action format?
- [ ] All empty states follow what/why/action format?
- [ ] Terminology matches canonical terms list?
- [ ] No fear language in security contexts?
- [ ] Numbers use correct locale formatting?
