# Design Operating System — Phase 0 Audit

> Data: 2026-07-31 | Status: Baseline

## Path Drift Resolution

### Document self-references — VERIFIED
- `docs/DESIGN_SYSTEM.md` — self-reference `docs/DESIGN_SYSTEM.md` (linha 274) correta
- `docs/KEROSENE_FRONTEND_ARCHITECTURE.md` — ja possui §8 Drift Note mapeando contract names → real paths
- `docs/STORYBOOK_SCREEN_INVENTORY.md` — ja possui nota de drift e atualizacao de paths
- `docs/PAYMENT_SWISS_ARMY.md` — referencia `frontend/lib/features/movement/` (correto)

### Contract name → real directory mapping
| Contract name | Real directory | Status |
|--------------|----------------|--------|
| `send` | `lib/features/movement/presentation/send/` | OK |
| `receive` | `lib/features/movement/presentation/receive/` | OK |
| `financial_activity` | `lib/features/movement/presentation/activity/` | OK |
| `admin` | `lib/features/web/` + `lib/features/web_admin/` | OK |
| (extra) | `lib/features/movement/` — hosts send/receive/activity | Documented |
| (extra) | `lib/features/ledger/` — local ledger sync | Documented |
| (extra) | `lib/features/landing/` — public web landing | Documented |

### Storybook path references
Todos os paths no inventario de storybook usam `lib/` como prefixo — correto para a estrutura atual.
A nota de drift de 2026-07-31 documenta a migracao de `features/wallet/` → `features/movement/` e `features/bitcoin_accounts/` → `features/financial_accounts/`.

## Component Inventory

### Design system components (lib/design_system/components/)
| Subdirectory | Files | Approx. usage |
|-------------|-------|---------------|
| `buttons/` | 3 (`app_button`, `animated_loading_button`, `bouncing_button`) | Alto (toda tela) |
| `cards/` | 1 (`app_card`) | Alto |
| `inputs/` | 1 (`app_text_field`) | Alto |
| `display/` | 1 (`animated_number_display`) | Medio (home, send) |
| `feedback/` | 4 (`state_feedback_view`, `app_notice`, `app_notification_surface`, `app_screen_feedback_host`) | Alto |
| `financial/` | 5 (`send_flow_chrome`, `amount_entry_surface`, `confirmation_surface`, `amount_calculator_toolbar`, `wallet_expand_chip`) | Medio (send flow) |
| `auth/` | 2 (`auth_primary_cta`, `auth_form_field`) | Medio (auth flow) |
| `generic/` | 11 (glass, logo, background, error dialog, etc.) | Alto |

### Oversized files
| File | Lines | Policy limit | Action |
|------|-------|-------------|--------|
| `amount_entry_surface.dart` | 2408 | 1000 | MUST split (Phase 7) |
| `home_screen_surface.dart` | 647 | 700 | OK, approaching limit |
| `home_screen.dart` | 487 | 700 | OK |
| `home_stage.dart` | 1251 | 1000 | Domain entity with JSON serialization — add `architecture-allow-large-file` annotation |

OBS: `home_stage.dart` (1251 linhas) e um arquivo de dominio com modelos de dados + JSON — nao e um widget monolitico. Justificativa para a annotation aceita.

### Raw Color usage in design_system/
11 arquivos usam `Color(0x...` inline. Theme files (`app_colors.dart`, `kerosene_brand_tokens.dart`, `*_surface_tokens.dart`, `monochrome_theme.dart`, `app_theme.dart`) sao exempt — sao os arquivos que DEFINEM os tokens. Component files que devem ser migrados para tokens semanticos:
- `amount_calculator_toolbar.dart`
- `wallet_expand_chip.dart`
- `send_flow_theme.dart`
- `amount_entry_surface.dart`
- `kerosene_education_dialog.dart`

## Golden Test Coverage

### Coverage matrix: golden tests × screens
| Golden test | Screen covered | Storybook story |
|------------|----------------|-----------------|
| `welcome_screen` | WelcomeScreen | App Flow |
| `login_screen` | LoginScreen | App Flow |
| `signup_screen` | SignupFlowScreen | App Flow |
| `emergency_recovery_screen` | EmergencyRecoveryScreen | App Flow |
| `server_unavailable_screen` | ServerUnavailableScreen | App Flow |
| `settings_screen` | SettingsScreen | App Flow |
| `send_money_screen` | SendMoneyScreen | App Flow |
| `receive_amount_screen` | ReceiveAmountScreen | App Flow |
| `receive_request_flow_screen` | ReceiveRequestFlowScreen | App Flow |
| `receive_nfc_flow_screen` | ReceiveNfcFlowScreen | App Flow |
| `home_receive_theater` | HomeScreen (receive theater) | App Flow |
| `wallet_flow_selector` | WalletFlowSelector | Wallet Flow |

### Gaps
- **Admin screens (16):** zero golden coverage. All 16 admin stories have no golden baselines.
- **Payment Intent states (6):** zero golden coverage. 6 storybook states with no goldens.
- **Bitcoin/Advanced:** zero golden coverage.
- **Transaction detail / activity:** zero golden coverage.
- **All golden tests use single resolution** (~430x6000 tall scroll). No multi-resolution baselines.

## Capture Tooling Inventory
| Tool | Path | Purpose |
|------|------|---------|
| `capture-device-screens.sh` | `tools/` | Device screenshot capture |
| `device-snapshot-goldens.sh` | `tools/` | Generate real-data goldens from device |
| `update-real-goldens.sh` | `tools/` | Update real golden baselines |
| `run-visual-e2e.sh` | `tools/` | Run visual E2E tests |
| `visual_app_harness.dart` | `integration_test/support/` | Boots real shell, unlocks PIN |
| `visual_capture.dart` | `integration_test/support/` | Native surface capture |
| `device_screen_gallery_export.dart` | `lib/core/debug/` | Debug gallery export |
| `real_golden_harness.dart` | `test/goldens/real_data/` | Real-data golden harness |
| Maestro flows | `maestro/flows/` | `capture_authenticated_screens.yaml`, `login_ui_then_capture.yaml` |

## Motion Token Inventory
`lib/core/motion/app_motion.dart` — 35+ named durations, 5 curves, utility functions (`stagger`, `exponentialBackoff`, `reduceMotion`, `duration`).

Tokens ja existentes por categoria implicita:
- **Functional:** `instant`, `fast` (120ms), `short` (180ms), `standard`/`emphasized` (via curve)
- **Continuity:** `pageIn` (136ms), `pageOut` (92ms), `route`
- **Brand:** `ceremonial` (2600ms), `secureLoop` (5200ms), `status` (1500ms)
- **Ambient:** `ambient` (20s), `calm` (1000ms), `slow` (600ms)
- **Loading:** `loadingMinimum` (3s), `loadingRetryMedium` (6s), `loadingTimeout` (15s)
- **Micro:** `microStagger` (50ms), `authStagger` (34ms), `listStagger` (60ms), `surfaceStagger` (28ms)
- **Security:** `passkeyPulse` (5s), `passkeyScene` (900ms), `totpTransition` (850ms)
- **Wallet:** `walletLoop` (4s), `odometerCeremony` (1s), `odometerUpdate` (700ms)
- **Notice:** `noticeHold` (3s), `notificationHold` (5s)
- **NFC:** `nfcSceneIntro` (1600ms), `nfcSceneReady` (3900ms)

A categorizacao existe implicitamente nos nomes. Phase 5 formaliza com enums + docstrings.

## Home Screen Decomposition
O home screen ja esta decomposto em arquivos separados com `RepaintBoundary`:
- `home_screen.dart` (487 linhas) — shell + callbacks
- `home_screen_balance.dart` — projecao financeira
- `home_screen_education.dart` — educacao progressiva
- `home_screen_navigation.dart` — navegacao responsiva
- `home_screen_send_method.dart` — metodo de envio
- `home_screen_payment_link.dart` — payment link entry
- `home_screen_surface.dart` (647 linhas) — superficie de acoes
- `home_screen_transactions.dart` — historico
- `home_layers.dart` — composicao de camadas com RepaintBoundary

O scene subsystem (`lib/features/home/scene/`) gerencia a camada de atmosfera de forma independente.

## Recommendations (Phase 0 closure)
1. Add `architecture-allow-large-file` annotation to `home_stage.dart` (1251 lines, domain entity)
2. `amount_entry_surface.dart` (2408 lines) is critical debt — split in Phase 7
3. Golden coverage gap for admin screens is acceptable (low user-facing priority)
4. Golden coverage gap for Payment Intent states should be addressed in Phase 6
5. Raw `Color(0x` in components (not theme files) should migrate to semantic tokens
