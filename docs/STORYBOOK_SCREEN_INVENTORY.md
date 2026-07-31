# Inventario de telas e cobertura do Storybook

Data da atualizacao: 2026-05-29 | Atualizado: 2026-07-31 (correcao de paths)

> **Nota de drift (2026-07-31):** Os paths abaixo ainda usam `lib/` como prefixo
> herdado da estrutura monorepo antiga. O prefixo correto atual e `lib/`.
> Alguns diretorios de features migraram — ex.: `features/wallet/` → `features/movement/`,
> `features/bitcoin_accounts/` → `features/financial_accounts/`.
> Consulte `docs/KEROSENE_FRONTEND_ARCHITECTURE.md` §8 para o mapa completo de drift.

Escopo analisado: `lib/features`, rotas mobile em
`lib/bootstrap/mobile_bootstrap.dart`, rotas web em
`lib/bootstrap/web_bootstrap.dart`, roteador admin em
`lib/features/web_admin/navigation/admin_content_router.dart` e stories
em `lib/storybook`.

## Resumo

- O package Flutter atual e `kerosene`; imports de Storybook/admin usam
  `package:kerosene/...`.
- O Storybook registra 29 stories de topo: `Kerosene/App Flow`,
  `Bitcoin/Advanced`, 6 estados diretos de Payment Intent, 6 estados diretos
  de receive requests, `Admin/Login` e uma story direta para cada
  `AdminRoute`.
- `Kerosene/App Flow` e a visao sequencial completa, com navegacao interna por
  dominio sem depender de backend real.
- As stories legadas duplicadas (`app_screen_stories`, `auth_stories`,
  `wallet_stories`, `ui_stories`, `shared_stories`) foram removidas.
- O admin nao deve renderizar placeholder para nenhuma rota de `AdminRoute`.
- `voucher` nao existe como feature ativa no frontend atual.

## Stories registradas

| Story | Finalidade |
| --- | --- |
| `Kerosene/App Flow` | Navegacao sequencial completa por entrada, app mobile, receber, deposito, web publico e admin. |
| `Bitcoin/Advanced` | Cold wallet com UTXOs, PSBT workflows, envio de PSBT assinada e tax events mockados. |
| `Payments/Intent Start` | Inicio do fluxo Payment Intent com recebedor e valor. |
| `Payments/Intent Capabilities` | Capacidades de recebimento consultadas para o recebedor. |
| `Payments/Intent Quote` | Quote com rota, taxas e total debitado. |
| `Payments/Intent Settled` | Pagamento confirmado e liquidado. |
| `Payments/Intent Failed` | Falha terminal do pagamento. |
| `Payments/Intent Missing Rail` | Recebedor sem trilho de recebimento ativo. |
| `Receive/Requests/Loading` | Estado loading da lista de receive requests dentro de Bitcoin Accounts. |
| `Receive/Requests/Empty` | Estado vazio da lista de receive requests dentro de Bitcoin Accounts. |
| `Receive/Requests/Pending` | Estado pendente/ativo da lista de receive requests dentro de Bitcoin Accounts. |
| `Receive/Requests/Paid` | Estado pago da lista de receive requests dentro de Bitcoin Accounts. |
| `Receive/Requests/Expired` | Estado expirado da lista de receive requests dentro de Bitcoin Accounts. |
| `Receive/Requests/Error` | Estado de erro da lista de receive requests dentro de Bitcoin Accounts. |
| `Admin/Login` | Login web admin isolado. |
| `Admin/Dashboard` | `AdminRoute.dashboard`. |
| `Admin/Monitoring` | `AdminRoute.monitoring`. |
| `Admin/Integrity Proofs` | `AdminRoute.transactions`. |
| `Admin/Lightning` | `AdminRoute.lightning`. |
| `Admin/On-chain` | `AdminRoute.onchain`. |
| `Admin/Hash Chain` | `AdminRoute.checks`. |
| `Admin/Payment Metrics` | `AdminRoute.paymentLinks`. |
| `Admin/Analytics` | `AdminRoute.analytics`. |
| `Admin/Volatility` | `AdminRoute.volatility`. |
| `Admin/Infrastructure` | `AdminRoute.companies`. |
| `Admin/Audit & Security` | `AdminRoute.audit`. |
| `Admin/Dispositivos autenticados` | `AdminRoute.authenticatedDevices`. |
| `Admin/Notifications` | `AdminRoute.notifications`. |
| `Admin/Settings` | `AdminRoute.settings`. |

## Cobertura por tela

### Entrada

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `WelcomeScreen` | `lib/features/auth/presentation/screens/welcome_screen.dart` | `Kerosene/App Flow` -> `/welcome` |
| `LoginScreen` | `lib/features/auth/presentation/screens/login_screen.dart` | `Kerosene/App Flow` -> `/login` |
| `EmergencyRecoveryScreen` | `lib/features/auth/presentation/screens/emergency_recovery_screen.dart` | `Kerosene/App Flow` -> `/recovery/emergency` |
| `PasskeyVerificationScreen` | `lib/features/auth/presentation/screens/passkey_verification_screen.dart` | `Kerosene/App Flow` -> `/passkey` |
| `SignupFlowScreen` | `lib/features/auth/presentation/screens/signup/signup_flow_screen.dart` | `Kerosene/App Flow` -> `/signup` |
| `ServerUnavailableScreen` | `lib/features/auth/presentation/screens/server_unavailable_screen.dart` | `Kerosene/App Flow` -> `/server-unavailable` |

### App mobile

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `HomeLoadingScreen` | `lib/features/home/presentation/screens/home_loading_screen.dart` | `Kerosene/App Flow` -> `/home_loading` |
| `HomeScreen` | `lib/features/home/presentation/screens/home_screen.dart` | `Kerosene/App Flow` -> `/home` |
| `BitcoinAccountsScreen` | `lib/features/bitcoin_accounts/presentation/bitcoin_accounts_screen.dart` | `Kerosene/App Flow` -> `/card`, `/bitcoin/advanced`; `Bitcoin/Advanced` |
| `TransactionStatementScreen` | `lib/features/transactions/presentation/screens/deposits_screen.dart` | `Kerosene/App Flow` -> `/history` |
| `SendMoneyScreen` | `lib/features/wallet/presentation/screens/send_money_screen.dart` | `Kerosene/App Flow` -> `/send-money` |
| `WithdrawScreen` | `lib/features/transactions/presentation/screens/withdraw_screen.dart` | `Kerosene/App Flow` -> `/withdraw/onchain`, `/withdraw/lightning` |
| `SettingsScreen` | `lib/features/settings/presentation/screens/settings_screen.dart` | `Kerosene/App Flow` -> `/settings` |
| `NotificationCenterScreen` | `lib/features/notifications/presentation/screens/notification_center_screen.dart` | `Kerosene/App Flow` -> `/notifications` |

### Payments

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `PaymentIntentFlowScreen` | `lib/features/payments/presentation/screens/payment_intent_flow_screen.dart` | `Payments/Intent Start`, `Payments/Intent Capabilities`, `Payments/Intent Quote`, `Payments/Intent Settled`, `Payments/Intent Failed`, `Payments/Intent Missing Rail`, `Kerosene/App Flow` -> `REMOVED_LEGACY_FINANCIAL_ROUTE`, `REMOVED_LEGACY_FINANCIAL_ROUTE`, `REMOVED_LEGACY_FINANCIAL_ROUTE` |

### Conta e seguranca

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `SecuritySettingsScreen` | `lib/features/profile/presentation/screens/security_settings_screen.dart` | `Kerosene/App Flow` -> `/account/security` com inventario de passkeys, TOTP, backup codes e PIN mockados. |
| `NotificationSettingsScreen` | `lib/features/profile/presentation/screens/notification_settings_screen.dart` | `Kerosene/App Flow` -> `/account/notifications` |
| `SovereigntyStatusScreen` | `lib/features/security/presentation/screens/sovereignty_status_screen.dart` | `Kerosene/App Flow` -> `/security/sovereignty` |

### Receber e deposito

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `DepositsScreen` | `lib/features/transactions/presentation/screens/deposits_screen.dart` | `Kerosene/App Flow` -> `/receive` |
| `ReceiveGatewayProvidersScreen` | `lib/features/transactions/presentation/screens/deposits_screen.dart` | `Kerosene/App Flow` -> `/receive/providers` |
| `BitcoinAccountsScreen` receive requests | `lib/features/bitcoin_accounts/presentation/bitcoin_accounts_screen.dart` | `Receive/Requests/Loading`, `Receive/Requests/Empty`, `Receive/Requests/Pending`, `Receive/Requests/Paid`, `Receive/Requests/Expired`, `Receive/Requests/Error`, `Kerosene/App Flow` -> `/receive/requests/loading`, `/receive/requests/empty`, `/receive/requests/pending`, `/receive/requests/paid`, `/receive/requests/expired`, `/receive/requests/error` |
| `ReceiveAmountScreen` | `lib/features/wallet/presentation/screens/receive_amount_screen.dart` | `Kerosene/App Flow` -> `/receive/amount/qr`, `/receive/amount/link`, `/receive/amount/nfc` |
| `ReceiveRequestFlowScreen` | `lib/features/wallet/presentation/screens/receive_request_flow_screen.dart` | `Kerosene/App Flow` -> `/receive/qr`, `/receive/onchain-confirming`, `/receive/onchain-identified` |
| `ReceivePaymentLinkScreen` | `lib/features/wallet/presentation/screens/receive_payment_link_screen.dart` | `Kerosene/App Flow` -> `/receive/payment-link`, `/receive/payment-link-paid` |
| `ReceiveNfcFlowScreen` | `lib/features/wallet/presentation/screens/receive_nfc_flow_screen.dart` | `Kerosene/App Flow` -> `/receive/nfc`, `/receive/onchain-nfc` |
| `DepositAmountScreen` | `lib/features/wallet/presentation/screens/deposit/deposit_amount_screen.dart` | `Kerosene/App Flow` -> `REMOVED_LEGACY_FINANCIAL_ROUTE` |
| `DepositMethodScreen` | `lib/features/wallet/presentation/screens/deposit/deposit_method_screen.dart` | `Kerosene/App Flow` -> `REMOVED_LEGACY_FINANCIAL_ROUTE` |
| `DepositLightningInvoiceScreen` | `lib/features/wallet/presentation/screens/deposit/deposit_lightning_invoice_screen.dart` | `Kerosene/App Flow` -> `REMOVED_LEGACY_FINANCIAL_ROUTE` |
| `DepositOnchainInvoiceScreen` | `lib/features/wallet/presentation/screens/deposit/deposit_onchain_invoice_screen.dart` | `Kerosene/App Flow` -> `REMOVED_LEGACY_FINANCIAL_ROUTE` |

### Web publico

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `KeroseneLandingPage` | `lib/features/landing/presentation/kerosene_landing_page.dart` | `Kerosene/App Flow` -> `/public/landing`, `/public/download` |
| `KerosenePublicStatusPage` | `lib/features/landing/presentation/kerosene_landing_page.dart` | `Kerosene/App Flow` -> `/public/status` |

### Admin web

| Tela | Arquivo | Storybook |
| --- | --- | --- |
| `AdminLoginScreen` | `lib/features/web_admin/screens/login/admin_login_screen.dart` | `Admin/Login`, `Kerosene/App Flow` -> `/admin/login` |
| `DashboardScreen` | `lib/features/web_admin/screens/dashboard/dashboard_screen.dart` | `Admin/Dashboard`, `Kerosene/App Flow` -> `/admin/dashboard` |
| `MonitoringScreen` | `lib/features/web_admin/screens/monitoring/monitoring_screen.dart` | `Admin/Monitoring`, `Kerosene/App Flow` -> `/admin/monitoring` |
| `TransactionsScreen` | `lib/features/web_admin/screens/transactions/transactions_screen.dart` | `Admin/Integrity Proofs`, `Kerosene/App Flow` -> `/admin/transactions` |
| `LightningScreen` | `lib/features/web_admin/screens/lightning/lightning_screen.dart` | `Admin/Lightning`, `Kerosene/App Flow` -> `/admin/lightning` |
| `OnchainScreen` | `lib/features/web_admin/screens/onchain/onchain_screen.dart` | `Admin/On-chain`, `Kerosene/App Flow` -> `/admin/onchain` |
| `ChecksScreen` | `lib/features/web_admin/screens/checks/checks_screen.dart` | `Admin/Hash Chain`, `Kerosene/App Flow` -> `/admin/checks` |
| `PaymentLinksScreen` | `lib/features/web_admin/screens/payment_links/payment_links_screen.dart` | `Admin/Payment Metrics`, `Kerosene/App Flow` -> `/admin/payment-links` |
| `AnalyticsScreen` | `lib/features/web_admin/screens/analytics/analytics_screen.dart` | `Admin/Analytics`, `Kerosene/App Flow` -> `/admin/analytics` |
| `VolatilityScreen` | `lib/features/web_admin/screens/volatility/volatility_screen.dart` | `Admin/Volatility`, `Kerosene/App Flow` -> `/admin/volatility` |
| `CompaniesScreen` | `lib/features/web_admin/screens/companies/companies_screen.dart` | `Admin/Infrastructure`, `Kerosene/App Flow` -> `/admin/companies` |
| `AuditScreen` | `lib/features/web_admin/screens/audit/audit_screen.dart` | `Admin/Audit & Security`, `Kerosene/App Flow` -> `/admin/audit` |
| `AuthenticatedDevicesScreen` | `lib/features/web_admin/screens/authenticated_devices/authenticated_devices_screen.dart` | `Admin/Dispositivos autenticados`, `Kerosene/App Flow` -> `/admin/authenticated-devices` |
| `NotificationsScreen` | `lib/features/web_admin/screens/notifications/notifications_screen.dart` | `Admin/Notifications`, `Kerosene/App Flow` -> `/admin/notifications` |
| `AdminSettingsScreen` | `lib/features/web_admin/screens/settings/admin_settings_screen.dart` | `Admin/Settings`, `Kerosene/App Flow` -> `/admin/settings` |

## Telas internas

Estas classes continuam privadas ao arquivo Dart e devem ser validadas pela tela
publica dona:

| Tela privada | Arquivo | Validacao |
| --- | --- | --- |
| `_PaymentLinkEntryScreen` | `lib/features/home/presentation/screens/home_screen_payment_link.dart` | `HomeScreen` |
| `_SendMethodScreen` | `lib/features/home/presentation/screens/home_screen_send_method.dart` | `HomeScreen` |
| `_AppEntryPinLockScreen` | `lib/features/security/presentation/widgets/app_entry_pin_gate.dart` | fluxo autenticado real |
| `_InternalTransferReviewScreen` | `lib/features/wallet/presentation/screens/send_money_screen_review.dart` | `SendMoneyScreen` |
| `ColdWalletCreationScreen` | `lib/features/bitcoin_accounts/presentation/bitcoin_accounts_screen.dart` | `BitcoinAccountsScreen` |

## Observacoes

- Storybook usa mocks e overrides locais. Nao deve depender de backend, camera,
  NFC, WebView ou sessao real.
- Estados criticos de receive requests agora tem stories diretas por estado:
  loading, vazio, pendente, pago, expirado e erro.
- Payment Intent, Emergency Recovery, Bitcoin Advanced e Account Security ja
  tem modulo frontend, contrato de service e cobertura Storybook.
