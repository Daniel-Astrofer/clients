# Flow: Wallet Switching

> Status: Draft | Applies-to: mobile · web
> Anchors: `lib/features/financial_accounts/presentation/widgets/wallet_flow_selector.dart`
> Last revised: 2026-07-31

## User objective chain

1. **View:** "What wallets do I have?"
2. **Compare:** "What's in each one?"
3. **Switch:** "Use this wallet now"
4. **Confirm:** "Home now shows this wallet's context"

Success metric:
- User can see all wallets with balances
- User understands custody type per wallet
- Switching is instant with clear confirmation
- Home balance updates to reflect selected wallet

---

## Screen sequence

```
Home (showing current wallet badge)
  │
  └─→ Wallet List (modal, bottom-up)
        Entry: user taps wallet badge or wallet selector
        Exit: wallet selected OR dismissed
        Dominant action: tap wallet row
        Secondary: create new wallet, view wallet details
        Motion: present bottom-up (260ms easeOutQuart)
        │
        └─→ Home (with new wallet context)
              Balance: odometer update (700ms) on real delta, instant on same value
              Badge: updates to show new wallet name + custody type
              Activity: filters to selected wallet's transactions
```

---

## State matrix

| State | Wallet List | Post-Switch |
|-------|-----------|------------|
| Loading | Fetching wallets + balances | Balance updating |
| Empty | No wallets (should never happen post-onboarding) | — |
| Partial | Some wallets loaded, balance pending | — |
| Error | Wallet fetch failed | Balance update failed |
| Offline | Last-known wallets shown, balances stale | Balance shows last-known + offline badge |
| Success | All wallets with balances | New wallet active, balance updated |
| Zero balance | Wallet shows R$ 0,00 | Home shows zero balance |

---

## Continuity contracts

- **Wallet badge → List:** Badge expands or the list appears to originate from the badge position
- **List → Home:** Selected wallet name + custody type appear in the badge. Balance updates via odometer ceremony (if value changed) or silently (if same)
- **Balance:** Never shows skeleton or blank. Preserve previous balance until new value arrives.
- **Activity list:** Filters to new wallet's transactions. Previous wallet's activity scrolls out, new scrolls in.

## Motion contract

- Wallet list modal: `KeroseneMotion.medium` (260ms, easeOutQuart) bottom-up
- Wallet list dismiss: `KeroseneMotion.pageOut` (92ms, easeInCubic)
- Balance update (delta > 0): `KeroseneMotion.odometerUpdate` (700ms, easeOutExpo)
- Balance update (same value): `KeroseneMotion.instant` (0ms)
- Activity filter transition: crossfade or instant — never staggered list animation

## Accessibility contract

- Wallet list: each row announces wallet name + balance + custody type
- Switch confirmation: `SemanticsService.announce('Carteira {nome} selecionada. Saldo: {valor}')`
- Balance: `semanticLabel: 'Saldo da carteira {nome}: R\$ {valor}'`

---

## Storybook coverage

| State | Story | Status |
|-------|-------|--------|
| Wallet list with balances | `Wallet Flow` stories | Exists |
| Wallet switch + balance update | `Kerosene/App Flow` → wallet selector | Exists |
| Empty wallet (zero balance) | Not covered | Gap |
| Offline wallet list | Not covered | Gap |
| Wallet fetch error | Not covered | Gap |
