# Kerosene Agent Definitions

> Prompts e definicoes de papeis para agentes que trabalham no frontend Kerosene.

## Estrutura

```
docs/agents/
├── README.md                 (este arquivo)
├── UI_FEATURE_AGENT.md       (prompt completo para agente de feature frontend)
└── roles/
    ├── flow-architect.md     (arquiteto de fluxo — contratos, estados, continuidade)
    ├── visual-director.md    (diretor visual — referencias, propostas, composicao)
    ├── motion-specialist.md  (especialista em movimento — continuidade, performance)
    ├── flutter-implementer.md (implementador Flutter — Riverpod, providers, testes)
    └── visual-critic.md      (critico visual — avaliacao objetiva contra rubric)
```

## Papeis

### Flow Architect
Nao escreve codigo. Responsavel por:
- Identificar objetivo do usuario
- Mapear entrada e saida
- Listar todos os estados
- Reduzir passos
- Detectar contradicoes entre telas
- Definir hierarquia de informacao
- Escrever contrato da tela

### Visual Director
Nao integra backend. Responsavel por:
- Analisar referencias
- Propor 2-3 direcoes visuais
- Trabalhar composicao, proporcao, densidade, personalidade
- Usar dados simulados
- Implementar propostas no storybook
- Gerar screenshots

### Motion Specialist
Responsavel por:
- Definir continuidade entre telas
- Implementar feedback de toque
- Definir animacoes de processamento e confirmacao
- Avaliar interrupcoes e reversibilidade
- Garantir suporte a reduceMotion
- Medir desempenho

### Flutter Implementer
Responsavel por:
- Conectar Riverpod, providers, navegacao e dados reais
- Manter view state separado da composicao visual
- Reutilizar componentes
- Implementar estados definidos no contrato
- Criar testes

### Visual Critic
Nao confia na descricao do implementador. Recebe:
- Contrato da tela
- Screenshots das referencias
- Screenshots da implementacao
- Video das interacoes
- Rubric de avaliacao
- Resultados de testes e perfil de desempenho

E produz uma lista objetiva de correcoes.

## Status

| Documento | Status |
|-----------|--------|
| `UI_FEATURE_AGENT.md` | A criar (Phase 4) |
| `roles/flow-architect.md` | A criar (Phase 4) |
| `roles/visual-director.md` | A criar (Phase 4) |
| `roles/motion-specialist.md` | A criar (Phase 4) |
| `roles/flutter-implementer.md` | A criar (Phase 4) |
| `roles/visual-critic.md` | A criar (Phase 4) |
