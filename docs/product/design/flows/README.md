# Flow Contracts

> Cada fluxo define a sequencia completa de telas, os estados por etapa,
> e os contratos de continuidade entre telas.

## Template

```markdown
# Flow: <nome>

## Objetivo do usuario
## Sequencia de telas (com criterios de entrada/saida)
## Matriz de estados (loading, empty, partial, error, offline, success, pending, cancelled, expired)
## Contratos de continuidade (o que persiste visualmente entre telas)
## Contrato de movimento (tokens pageIn/pageOut, transicoes de continuidade, momentos ceremonias)
## Cobertura Storybook (story para cada estado; gaps → backlog)
```

## Fluxos

| Fluxo | Arquivo | Status | Ancora de codigo |
|-------|---------|--------|-----------------|
| Send Money | `send-money.md` | A criar | `lib/features/movement/presentation/send/` |
| Receive Money | `receive-money.md` | A criar | `lib/features/movement/presentation/receive/` |
| Wallet Switching | `wallet-switching.md` | A criar | `lib/features/financial_accounts/presentation/widgets/wallet_flow_selector.dart` |
| Transaction History | `transaction-history.md` | A criar | `lib/features/movement/presentation/activity/` |
| Onboarding | `onboarding.md` | A criar | `lib/features/home/presentation/screens/onboarding_steps_screen.dart` |

## Convencoes

- Telas sao referenciadas pelo nome da classe Dart (ex: `SendMoneyScreen`)
- Estados seguem a nomenclatura do `StateFeedbackView`
- Tokens de movimento referenciam `KeroseneMotion` (ex: `KeroseneMotion.pageIn`)
- Cada estado listado deve ter cobertura Storybook ou issue de backlog
