# Screen Contracts

> Cada tela define o objetivo do usuario, a pergunta dominante, a acao dominante,
> e TODOS os estados possiveis.

## Template

```markdown
# Screen: <nome>

## Objetivo do usuario
## Pergunta dominante (a unica coisa que o usuario quer saber)
## Acao dominante (CTA primaria — pill, outlined)
## Acoes secundarias
## Todos os estados (loading, empty, partial, error, offline, success, pending, cancelled, expired)
## Continuidade visual (o que veio da tela anterior, o que vai para a proxima)
## Contrato de movimento (entrada, saida, momentos de marca, ambiente)
## Contrato de acessibilidade (ordem de foco, live regions, haptics)
## Contrato de performance (frame budget, isolamento de camadas)
## Contrato de golden (resolucoes obrigatorias)
```

## Telas

| Tela | Arquivo | Status | Ancora de codigo |
|------|---------|--------|-----------------|
| Home | `home-screen.md` | A criar | `lib/features/home/presentation/screens/home_screen.dart` |
| Send Review | `send-review-screen.md` | A criar | `lib/features/movement/presentation/send/send_money_screen.dart` |
| Payment Processing | `payment-processing-screen.md` | A criar | Auth → processing → result transition |
| Transaction Detail | `transaction-detail-screen.md` | A criar | Movement activity detail |
