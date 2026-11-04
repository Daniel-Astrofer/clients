# Plano de Arquitetura 240 FPS: Conexão API, SWR e Otimização de Telas (Flutter 3.47 & Dart 3.13)

Este documento estabelece o plano técnico e arquitetural para sustentar uma taxa de atualização de **240 FPS estáveis** no cliente Kerosene (Flutter 3.47 / Dart 3.13), operando com um orçamento rígido de **4,16 ms por frame** (sendo 2,08 ms para UI Build na CPU e 2,08 ms para Raster na GPU).

---

## 1. Princípios e Diretrizes do Projeto

1. **Design UI/UX Intocado:** Nenhuma alteração visual, de fluxo, de cores ou de comportamento aparente na interface do usuário.
2. **Tráfego 100% Tor:** Todas as requisições passam pela camada de rede onion/SOCKS5. O gerenciamento de concorrência é mandatório para não saturar os circuitos locais do Tor.
3. **Opção B (Dart 3.13 Puro sem Geradores Pesados):** Utilização estrita de `Primary Constructors` e `Extension Types` (`extension type const TxId(String raw)`), garantindo custo zero de alocação de memória na Heap e reduzindo o acionamento do Garbage Collector (*Stop-The-World*).
4. **Isolamento de Parsing (Thread Merge Protection):** Com a fusão da UI Thread com a Platform Thread nativa no Flutter, nenhum processamento síncrono de JSON de 2 MB pode rodar na UI Isolate. A decodificação ocorre 100% em Isolates descartáveis (`Isolate.run` + `TransferableTypedData`).
5. **Cache em Disco Criptografado & ETag:** SWR (*Stale-While-Revalidate*) instantâneo (0 ms) a partir de snapshot criptografado em disco e validação via `If-None-Match` / `ETag` (HTTP 304).

---

## 2. Roteiro Passo a Passo de Implementação

### Etapa 1: Maestro de Requisições, Tor Multiplexing & Parsing Isolado Zero-Allocation
* **Single-Flight Coalescing (Multiplexador):** Deduplicação de requisições concorrentes idênticas numa janela de 2 segundos com base na chave combinada `(Method + Url + QueryParams + BodyHash)`.
* **Interaction Budget Gate:** Pausa de chamadas de background durante scrolls ou transições de alta taxa de quadros, reservando a CPU para o frame.
* **Isolate Worker Zero-Copy:** Decodificação de respostas binárias via `TransferableTypedData` fora da thread principal.
* **DTOs com Extension Types:** Modelos sem `freezed` para eliminar overhead de heap e pausas do GC.

### Etapa 2: Cache em Disco Criptografado & Suporte ETag (HTTP 304)
* **SWR Instantâneo (0 ms):** Carregamento imediato do cache criptografado persistido em disco para transações, saldos e dashboard.
* **Interceptor ETag / If-None-Match:** Envio de cabeçalho condicional.
* **Tratamento de HTTP 304 Not Modified:** Resposta sem corpo que mantém o estado da tela silenciosamente, sem emitir rebuilds desnecessários no Riverpod.

### Etapa 3: Sincronização em Tempo Real (WebSocket Primário + Polling Fallback 5s)
* **WebSocket como Fonte da Verdade:** Payloads recebidos nos tópicos STOMP (`/transactions`, `/balance`, `/topic/btc-price`) alimentam o estado diretamente na memória.
* **Eliminação de Refreshes Reflexos:** Remoção do disparo de `refreshFinancialProjection(forceFullHistory: true)` no recebimento de notificações.
* **Controle Estrito de Polling:**
  * WebSocket Conectado: Polling desativado (0 requisições).
  * WebSocket Desconectado: Fallback no intervalo exato de **5 segundos**.
* **Reconciliação na Reconexão:** Re-sincronização via ETag disparada apenas ao restabelecer a conexão.

### Etapa 4: Blindagem das Telas, Shaders, Vetores Binários & Telemetria 240 Hz
* **Isolamento de Rebuilds na UI:** Refatoração de widgets com seletores atômicos `ref.watch(provider.select(...))`.
* **Otimização do Fragment Shader:** Passagem de uniformes no `gemini_glow_background.dart` usando buffer plano pré-alocado `Float32List`.
* **Congelamento de Gráficos:** Congelamento do re-render de curvas (`fl_chart`) durante transições de rota.
* **Compilação Binária de Vetores:** Adoção de `vector_graphics_compiler` com `--tessellate` para ícones `.vec` (rasterização sub-milissegundo).
* **Painel de Telemetria 240 Hz (Dev/Profile):** Monitor contínuo via `SchedulerBinding.addTimingsCallback` auditando limites de 2,08 ms para Build e 2,08 ms para Raster.

---

## 3. Matriz de Arquivos do Projeto

| Camada | Arquivo | Status | Função Principal |
| :--- | :--- | :--- | :--- |
| **Configuração** | `pubspec.yaml` | Modificado | Adicionar `vector_graphics` e transformer `vector_graphics_compiler`. |
| **Rede** | `lib/core/network/request_coalescer.dart` | **Novo** | Deduplicação de requisições ativas (*Single-Flight*). |
| **Rede** | `lib/core/network/isolate_data_decoder.dart` | **Novo** | Decodificação de JSON via `Isolate.run` e `TransferableTypedData`. |
| **Rede** | `lib/core/network/encrypted_etag_cache_interceptor.dart` | **Novo** | Gerenciamento de ETag e cache criptografado com suporte a HTTP 304. |
| **Rede** | `lib/core/network/api_client.dart` | Modificado | Integração do coalescer, isolamento e interceptor ETag. |
| **Segurança** | `lib/app/security/local_transaction_history_store.dart` | Modificado | Persistência criptografada de snapshots de dados e ETags. |
| **Dados** | `lib/features/movement/data/datasources/transaction_remote_datasource.dart` | Modificado | Delegação de parsing de 2 MB para Isolate. |
| **Dados** | `lib/features/financial_accounts/data/datasources/wallet_remote_datasource.dart` | Modificado | Parsing isolado de carteiras e saldos. |
| **Entidades** | `lib/features/movement/data/entities/transaction_dto.dart` | **Novo** | DTOs com `Extension Types` do Dart 3.13. |
| **Entidades** | `lib/features/financial_accounts/data/entities/wallet_dto.dart` | **Novo** | DTOs com `Primary Constructors` do Dart 3.13. |
| **Tempo Real** | `lib/core/services/balance_websocket_service.dart` | Modificado | Tratamento de eventos STOMP em memória. |
| **Tempo Real** | `lib/features/financial_accounts/presentation/providers/balance_websocket_provider.dart` | Modificado | Polling fallback 5s e remoção de pull reflexo forçado. |
| **Tempo Real** | `lib/features/financial_accounts/presentation/providers/financial_refresh.dart` | Modificado | Reconciliação pós-queda unificada. |
| **Providers** | `lib/features/movement/providers/transaction_provider.dart` | Modificado | Upsert atômico de transações na memória. |
| **Providers** | `lib/features/financial_accounts/presentation/providers/wallet_provider.dart` | Modificado | Upsert atômico de saldos na memória. |
| **Apresentação** | `lib/features/home/presentation/screens/home_screen.dart` | Modificado | Remoção de rebuilds forçados e acoplamento a seletores atômicos. |
| **Apresentação** | `lib/features/home/presentation/layers/home_layers.dart` | Modificado | Isolamento de camadas e RepaintBoundary cirúrgico. |
| **Apresentação** | `lib/features/home/presentation/widgets/animated_balance_display.dart` | Modificado | Seletor granular `.select()` de saldo. |
| **Apresentação** | `lib/features/home/presentation/widgets/home_bitcoin_market_chart_card.dart` | Modificado | Congelamento de animação durante gestos. |
| **Apresentação** | `lib/features/movement/presentation/activity/statement_screen.dart` | Modificado | Hidratação instantânea SWR a partir do disco criptografado. |
| **Renderização** | `lib/features/home/scene/renderer/gemini_glow_background.dart` | Modificado | Passagem de uniformes com `Float32List` plano sem alocação. |
| **Renderização** | `lib/features/home/scene/renderer/media_layer.dart` | Modificado | Suporte a vetores binários `.vec`. |
| **Telemetria** | `lib/core/performance/frame_budget_monitor_240hz.dart` | **Novo** | Alerta visual de frames > 2,08 ms (Build/Raster) e telemetria Tor. |
| **Performance** | `lib/core/performance/app_interaction_busy.dart` | Modificado | Gate de interação para pausar rede de background. |
