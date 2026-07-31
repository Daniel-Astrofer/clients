# Screen: Home

> Status: Draft | Applies-to: mobile · web
> Anchor: `lib/features/home/presentation/screens/home_screen.dart`
> Last revised: 2026-07-31

## User goal

See financial status at a glance and initiate the next action.

## Dominant question

"Exactly how much money do I have, and what can I do with it?"

## Dominant action

Send money (primary financial action, outlined pill button).

## Secondary actions
- Receive money
- View transaction history (tap activity row or "Ver todas")
- Switch wallet (tap wallet badge)
- Scan QR code (for payment)
- View market chart/info
- Access education content

---

## Information hierarchy (top to bottom)

1. **Balance** — Playfair Display 48px, w590, #F7F8F8 (Snow). Dominant typographic presence.
2. **Wallet badge** — Wallet name + custody type + sync status. Adjacent to balance.
3. **Action cluster** — Send (primary, outlined pill) + Receive (secondary, ghost). Below balance.
4. **Market/education** — Communication stage, server-driven. Below actions.
5. **Activity strip** — Last ~5 transactions. Below market.
6. **Navigation** — Bottom bar (mobile) or sidebar (desktop).

---

## All states

| State | Behavior |
|-------|----------|
| **Loading (first launch)** | Full-screen branded loader (`KeroseneLogoLoadingView`) |
| **Loaded (normal)** | Balance + wallet + actions + activity |
| **Empty (no transactions)** | Balance + actions, activity area shows "Nenhuma movimentacao" with education |
| **Empty (zero balance)** | Balance shows R$ 0,00, actions still available, market still shows |
| **Offline** | Last-known balance + "Offline" badge + stale indicator on activity |
| **Offline (first launch)** | Startup connection screen (`startup_connection_loading_screen.dart`) |
| **Error (sync failed)** | Last-known data + `StateFeedbackView` error banner at top (persistent, not SnackBar) |
| **Refreshing** | Pull-to-refresh: preserve all data, show subtle sync indicator (not skeleton) |
| **Education (new user)** | Progressive education cards below activity, not above balance |
| **Market stage active** | Server-driven communication between balance and activity |
| **Payment link scanner** | QR scanner overlay from home (payment link entry) |

---

## 6-Stage decomposition

```
HomeStageAtmosphere       — Aurora/glow, ambient background (RepaintBoundary #1)
HomeFinancialProjection   — Balance, wallet badge, sync status (RepaintBoundary #2)
HomeActionStage           — Send/Receive/Scan action cluster (RepaintBoundary #3)
HomeActivityStage         — Transaction list + filter chips (RepaintBoundary #4)
HomeEducationStage        — Progressive education cards (RepaintBoundary #5)
HomeNavigationStage       — Bottom bar or sidebar (RepaintBoundary #6)
```

Each stage is an independent `Consumer` + `RepaintBoundary`. A provider update in one stage must not trigger rebuilds in sibling stages.

---

## Continuity

### From previous screens
- **From onboarding:** First-arrival state with education stage active
- **From send/receive result:** Balance updated, new transaction at top of activity
- **From wallet switch:** Balance updated for selected wallet, activity filtered

### To next screens
- **To send:** Wallet context + balance carried to send flow
- **To receive:** Wallet context carried to receive flow
- **To activity list:** Current filter state carried
- **To wallet list:** Current wallet pre-selected in list

---

## Motion contract

- **Balance update (real delta):** Odometer ceremony (1000ms first, 700ms subsequent)
- **Balance update (same value/tab switch):** Instant (no animation)
- **Activity refresh:** New items appear without list animation (preserve scroll position)
- **Market stage enter:** `fadeSlideDown` (420ms, easeOutCubic)
- **Market stage exit:** `fade` (280ms, easeIn)
- **Ambient aurora:** 20s slow displacement, independent `RepaintBoundary`, reduceMotion removes entirely
- **Page transitions:** `KeroseneMotion.pageIn`/`pageOut` for push/pop

---

## Accessibility contract

- Balance: `semanticLabel: 'Saldo total: R\$ {valor}'` or per-wallet
- Wallet badge: `semanticLabel: 'Carteira {nome}, {custodia}. Toque para trocar.'`
- Send button: `semanticLabel: 'Enviar dinheiro'`
- Receive button: `semanticLabel: 'Receber dinheiro'`
- Activity rows: each announces type + amount + status
- Market stage: announces title text, skips decorative glow
- Pull-to-refresh: announces "Atualizando" / "Atualizado"

---

## Performance contract

- Profile mode: maintain 60fps during scroll + ambient animation
- Ambient aurora: isolated `RepaintBoundary`, never rebuilds financial tree
- Activity list: no per-item blur or CustomPainter
- Balance: odometer uses composited layers, not relayout
- `reduceMotion`: removes ambient + collapses balance animation to instant

---

## Golden contract

5 resolutions:
- 390 × 844 (Compact)
- 600 × 960 (Medium)
- 1024 × 768 (Expanded)
- 1440 × 900 (Wide)
- 1920 × 1080 (Wide large)

Per state: loaded (normal), empty (no tx), offline, education active.

---

## Verification

- [ ] Balance has greatest typographic weight on screen?
- [ ] Send action is visually dominant over Receive?
- [ ] 6 stages isolated with RepaintBoundary?
- [ ] Ambient animation doesn't rebuild financial widgets?
- [ ] All states in matrix implemented or backlogged?
- [ ] Activity rows have semantic labels?
- [ ] Offline shows last-known data, not blank?
- [ ] Education doesn't compete with balance for dominance?
