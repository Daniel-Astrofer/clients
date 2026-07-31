# Interaction Principles

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

The design system defines how components look. This document defines how users move through them — the traversal model, when to reveal complexity, how screens relate, and what happens during loading, error, and confirmation.

---

## 1. Traversal model

### The Kerosene flow pattern

```
Home (hub)
  ├─→ Select (wallet, recipient, method)
  │     └─→ Configure (amount, fee, options)
  │           └─→ Review (confirm all parameters)
  │                 └─→ Authorize (PIN, passkey)
  │                       └─→ Process (animation, wait)
  │                             └─→ Result (success, pending, failure)
  │                                   └─→ Detail (transaction record)
  └─→ Activity (history, filtered)
```

**Rules:**
- Each step has exactly ONE dominant action
- Forward progression only — the user moves right through the flow
- Back is always available (back swipe, back button, or explicit "cancel" on authorization)
- The Review step is mandatory for any financial operation — no "one-tap send"
- Authorization is a distinct step with its own screen/sheet, never an inline dialog

### Navigation methods

| Transition | Method | When |
|-----------|--------|------|
| Push (horizontal) | `keroseneHorizontalRoute` | Forward in flow, detail from list |
| Pop (horizontal reverse) | Back gesture / button | Return to previous step |
| Present (bottom-up) | `.pushFromBottom()` | Modal choices (method selector, wallet picker) |
| Dismiss (swipe down) | Drag handle or swipe | Close modal |
| Inline expand | `AnimatedContainer` | Progressive disclosure within a screen |

---

## 2. Progressive disclosure

### When to reveal complexity

| Complexity | Default | Revealed when |
|-----------|---------|---------------|
| Fee rate selection | "Standard" (single estimate) | User taps "Fee options" disclosure |
| UTXO selection | Automatic (coin selection) | User enters Bitcoin Accounts → Advanced |
| Lightning invoice decode | Automatic | Shown in review step |
| On-chain confirmation target | "~30 minutes" | User taps "Network details" |
| Cold wallet PSBT | Hidden | User selects cold wallet as source |
| Custody type detail | Badge only (e.g., "Cold") | User taps badge → full explanation |

### Disclosure pattern
```dart
// Preferred: inline expansion
ExpansionTile(title: "Fee options", children: [...])

// Also acceptable: navigates to sub-screen
GestureDetector(onTap: () => context.push('/send/fees'), child: ...)

// Never: modal dialog for configuration
```

---

## 3. Screen relationships

### Parent → Child (push)
- Child inherits parent's theme and motion context
- Back returns to parent in the same state (preserve scroll position)
- Parent is visible during the slide transition
- Example: Home → Send Money

### Modal (present)
- Modal is independent — dismiss returns to caller
- Semi-transparent scrim behind modal
- Drag handle for dismiss (mobile), close button (desktop)
- Example: Wallet selector, method picker

### Sibling (tab switch)
- Preserves each sibling's state independently
- No cross-sibling animation (instant switch or short crossfade)
- Example: Home tabs (if any), admin sidebar sections

---

## 4. State feedback

### Loading
- **First load:** Full-screen branded loader (`KeroseneLogoLoadingView`)
- **Refresh with existing data:** Subtle sync indicator, preserve previous state
- **Action in progress:** Button enters processing state (animated glyph, not spinner)
- **Minimum display time:** 3s (`KeroseneMotion.loadingMinimum`) to avoid flash

### Empty
- **First use:** Illustration + "Here's where your [X] will appear" + optional education
- **After use:** "No [X] yet" with contextual action (e.g., "Send your first payment")
- Never: blank screen or just an icon

### Error
- **Inline:** `StateFeedbackView` with error variant — what happened, why, action to take
- **Persistent:** Error stays until user acts — no auto-dismiss
- **Recoverable:** Retry button
- **Non-recoverable:** Contact support link
- Never: `SnackBar` for operation failures

### Offline
- **Indicator:** Subtle bar at top (not blocking content), "Offline" with last sync time
- **Preserved state:** Show last-known data with "Offline" watermark
- **Auto-retry:** Pulse every 4s (`KeroseneMotion.offlineRetryInterval`)
- Never: replace entire screen with "No connection"

### Success
- **Financial confirmation:** Brand animation (Rive) + brief summary
- **Non-financial:** Brief notice, auto-dismiss after hold duration
- **Return:** Auto-navigate to next screen after ceremonial duration

---

## 5. Touch & input

### Haptic mapping

| Event | Haptic | When |
|-------|--------|------|
| Navigation (light) | `HapticFeedback.lightImpact()` | Tab switch, disclosure toggle |
| Selection (medium) | `HapticFeedback.mediumImpact()` | Wallet select, method choose |
| Action (medium) | `HapticFeedback.mediumImpact()` | Button press (send, confirm) |
| Error (heavy) | `HapticFeedback.heavyImpact()` | Authorization failure, insufficient funds |
| Success (double light) | `HapticFeedback.lightImpact()` × 2 | Payment confirmed |

References: `lib/design_system/foundation/interaction/kerosene_interaction.dart`

### Touch targets
- Minimum: 44pt × 44pt (matches Material guidelines)
- Financial actions: 48pt × 48pt minimum
- List rows: full-width tappable, minimum 48pt height
- No: text-only tappable labels smaller than 44pt

---

## 6. Destructive actions

### Confirmation pattern
```
1. User taps destructive action (e.g., "Remove wallet")
2. Confirmation sheet slides up (NOT a dialog)
3. Sheet explains: what will happen, whether it's reversible, any consequences
4. Two buttons: "Cancel" (secondary, ghost) + "Remove" (primary, outlined pill)
5. After confirmation: action executes → result notice
```

### Reversibility
- Transactions: NOT reversible on-chain (make this clear in review)
- Internal operations: reversible where possible (undo for 5s via notice action)
- Settings changes: always reversible

---

## Token & file map

| Concept | Source file |
|---------|------------|
| Navigation transitions | `lib/core/navigation/app_page_transitions.dart` |
| Haptics | `lib/design_system/foundation/interaction/kerosene_interaction.dart` |
| State feedback widget | `lib/design_system/components/feedback/state_feedback_view.dart` |
| Notice system | `lib/design_system/components/feedback/app_notice.dart` |
| Loading view | `lib/design_system/components/generic/kerosene_logo_loading_view.dart` |
| Responsive breakpoints | `lib/core/responsive/kerosene_responsive.dart` |

---

## Do / Don't

- [ ] DO use the Home → Select → Configure → Review → Authorize → Result pattern for financial flows
- [ ] DO keep exactly one dominant action per screen
- [ ] DO preserve previous state during refresh — never skeleton after first load
- [ ] DO use persistent inline error states, never auto-dismiss SnackBars
- [ ] DO confirm destructive actions with a sheet, not a dialog
- [ ] DO maintain minimum 44pt touch targets, 48pt for financial actions
- [ ] DON'T skip the Review step for any financial operation
- [ ] DON'T use modal dialogs for configuration — use sheets or inline expansion
- [ ] DON'T auto-dismiss errors
- [ ] DON'T replace entire screen for offline state

---

## Verification

- [ ] Every financial flow includes a Review step?
- [ ] Error states are persistent (not auto-dismissing)?
- [ ] Touch targets ≥44pt (48pt for financial)?
- [ ] Destructive actions have confirmation sheets?
- [ ] Haptics follow the mapping table?
