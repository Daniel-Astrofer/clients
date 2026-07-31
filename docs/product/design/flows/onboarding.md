# Flow: Onboarding

> Status: Draft | Applies-to: mobile
> Anchors: `lib/features/home/presentation/screens/onboarding_steps_screen.dart`
> Last revised: 2026-07-31

## User objective chain

1. **Welcome:** "What is Kerosene?"
2. **Create/Restore:** "Set up my wallet"
3. **Security:** "Protect my access"
4. **First deposit:** "Put money in"
5. **Ready:** "Start using Kerosene"

Success metric:
- User completes setup without confusion
- Security setup is clear and not anxiety-inducing
- First deposit is guided
- Home screen is welcoming on first arrival

---

## Screen sequence

```
Welcome Screen
  Entry: app first launch
  Exit: user chooses create or restore
  Dominant action: "Criar carteira" (primary), "Restaurar" (secondary)
  Motion: ambient brand welcome (Rive)
  │
  ├─→ Create Wallet Flow
  │     ├─→ Wallet Creation (automatic, show progress)
  │     ├─→ Recovery Phrase (display, confirm write-down)
  │     └─→ Phrase Verification (confirm 2-3 words)
  │
  ├─→ Restore Wallet Flow
  │     └─→ Enter Recovery Phrase (12/24 words)
  │
  ├─→ PIN Setup
  │     Entry: wallet created/restored
  │     Exit: PIN confirmed (entered twice, matching)
  │     Motion: monochrome theme
  │
  ├─→ Passkey Setup (optional but encouraged)
  │     Entry: PIN set
  │     Exit: passkey registered or skipped
  │     Motion: passkey scene (900ms)
  │
  ├─→ First Deposit (optional, can skip)
  │     Entry: security complete
  │     Exit: deposit initiated or skipped
  │     Education: "Deposit to get started"
  │
  └─→ Home (first arrival)
        Entry: onboarding complete
        Education stage visible: progressive tips
        Balance ceremony on first non-zero balance
```

---

## State matrix

| State | Welcome | PIN Setup | Passkey | First Deposit | Home |
|-------|---------|----------|---------|--------------|------|
| Loading | — | — | Registering | — | First sync |
| Error | — | — | Registration failed | — | Sync failed |
| Offline | — | PIN works offline | Needs network | Needs network | Limited data |
| Skip | — | PIN required | Passkey skippable | Deposit skippable | — |
| Success | → Create/Restore | → Passkey | → Deposit | → Home | Ready |

---

## Motion contract

- Welcome → Create/Restore: `KeroseneMotion.pageIn` (136ms)
- PIN: monochrome theme, `KeroseneMotion.medium` (260ms)
- Passkey: `KeroseneMotion.passkeyScene` (900ms), `KeroseneMotion.passkeyPulse` (5000ms)
- First deposit → Home: `KeroseneMotion.ceremonial` (brief, 1000ms)

## Education contract

Home shows progressive education for new users:
- Day 1: "Your wallet is ready" + send/receive intro
- Day 2-3: custody type explanation
- Week 1: Lightning vs on-chain
- Month 1: cold wallet intro

Education must never compete with financial data for visual dominance.

---

## Storybook coverage

| State | Story | Status |
|-------|-------|--------|
| Welcome | `Kerosene/App Flow` → `/welcome` | Exists |
| Signup | `Kerosene/App Flow` → `/signup` | Exists |
| PIN entry | App Flow | Exists |
| Passkey | `Kerosene/App Flow` → `/passkey` | Exists |
| Home first arrival | `Kerosene/App Flow` → `/home` with education | Exists |
| Recovery phrase | Not covered | Gap |
| Restore flow | Not covered | Gap |
