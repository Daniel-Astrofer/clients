# Kerosene Design Operating System

> Camada acima do design system que define como a Kerosene pensa e se comporta.
> O design system diz *quais componentes existem*. O Design OS diz *como compo-los em uma experiencia*.

## Estrutura

```
docs/product/design/
├── README.md                    (este arquivo)
├── 00-audit.md                  (auditoria baseline — paths, componentes, gaps)
│
├── product-principles.md        (6 principios de produto — o que guia decisoes)
├── visual-language.md           (linguagem visual — composicao, densidade, profundidade)
├── interaction-principles.md    (como o usuario percorre operacoes)
├── motion-system.md             (categorias de animacao — funcional, continuidade, marca, ambiente)
├── content-language.md          (voz, tom, terminologia)
├── responsive-strategy.md       (breakpoints, comportamento adaptativo)
├── accessibility-rules.md       (contraste, semantica, alvos de toque, reduceMotion)
├── anti-patterns.md             (padroes proibidos — o que NAO fazer)
├── design-review-rubric.md      (avaliacao objetiva de 100 pontos)
├── component-patterns.md        (10 padroes canonicos Kerosene)
├── performance-budget.md        (orcamento de performance para animacao)
│
├── flows/                       (contratos de fluxo — sequencia, estados, continuidade)
│   ├── send-money.md
│   ├── receive-money.md
│   ├── wallet-switching.md
│   ├── transaction-history.md
│   └── onboarding.md
│
├── screens/                     (contratos de tela — objetivo, acao dominante, estados)
│   ├── home-screen.md
│   ├── send-review-screen.md
│   ├── payment-processing-screen.md
│   └── transaction-detail-screen.md
│
└── references/                  (atlas de referencias comentadas)
    ├── home/
    ├── payments/
    ├── wallet/
    ├── transaction-status/
    └── desktop/
```

## Ordem de verdade

Quando um agente precisa tomar uma decisao de design, ele consulta nesta ordem:

1. `product-principles.md` — o que a Kerosene valoriza
2. `flows/<flow>.md` — contrato do fluxo especifico
3. `screens/<screen>.md` — contrato da tela especifica
4. `visual-language.md` — regras de composicao visual
5. `motion-system.md` — que animacao usar e quando
6. `anti-patterns.md` — o que NAO fazer
7. `design-review-rubric.md` — como validar o resultado
8. `../DESIGN_SYSTEM.md` — tokens e componentes concretos
9. `references/` — exemplos comentados

## Status dos documentos

| Documento | Status | Data |
|-----------|--------|------|
| `00-audit.md` | Baseline | 2026-07-31 |
| `product-principles.md` | A criar (Phase 1) | — |
| `visual-language.md` | A criar (Phase 1) | — |
| `interaction-principles.md` | A criar (Phase 1) | — |
| `motion-system.md` | A criar (Phase 1) | — |
| `content-language.md` | A criar (Phase 1) | — |
| `responsive-strategy.md` | A criar (Phase 1) | — |
| `accessibility-rules.md` | A criar (Phase 1) | — |
| `anti-patterns.md` | A criar (Phase 1) | — |
| `design-review-rubric.md` | A criar (Phase 1) | — |
| `component-patterns.md` | A criar (Phase 4) | — |
| `performance-budget.md` | A criar (Phase 6) | — |
| `flows/*.md` | A criar (Phase 2) | — |
| `screens/*.md` | A criar (Phase 2) | — |
| `references/*.md` | A criar (Phase 3) | — |

## Manutencao

- Cada documento tem um responsavel (a definir)
- Revisoes sao registradas no topo de cada arquivo
- O `00-audit.md` e atualizado a cada fase concluida
- Este README e o indice canonico — qualquer novo documento deve ser registrado aqui
