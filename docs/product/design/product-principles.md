# Product Principles

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

Design systems define tokens and components. They don't define how to make product decisions. When an agent encounters a choice — "should this information be visible immediately or behind a tap?" — the design system is silent. These principles fill that gap. They are the decision layer above tokens.

---

## Principles

### 1. Money before decoration

**Definition:** The user's balance, the source of funds, and the next available financial action must be understood before any promotional, educational, or atmospheric element.

**Kerosene example:** On Home, the balance claims typographic dominance (Playfair Display, w590, 48px). The send/receive cluster sits immediately below. Market chart comes after. Education is last.

**Anti-example:** A home screen where a greeting, market chart, or promotional card occupies more visual weight than the balance.

**Governs:** Home screen hierarchy, send flow entry, wallet selector ordering.

### 2. Visible security without anxiety

**Definition:** The interface communicates protection through clarity, confirmation, and predictability — never through constant alerts, warning icons, or fear-based language.

**Kerosene example:** The PIN gate is a calm monochrome surface. Authorization steps are sequenced with clear labels. Passkey verification shows a single animated glyph, not a list of security checks.

**Anti-example:** Red warning banners for normal operations. "Your funds are at risk" language for routine actions. Security theater (multiple confirmations for low-risk operations).

**Governs:** PIN/authorization screens, security settings, cold wallet access, transaction confirmation.

### 3. Progressive complexity

**Definition:** The common user sees direct actions: send, receive, balance. Blockchain details (UTXO selection, fee rate, confirmation depth), Lightning routing, custody type distinctions, and cold wallet management appear only when the user explicitly requests them or when the context makes them necessary.

**Kerosene example:** Send flow defaults to "fast" with a single fee estimate. Advanced fee control is behind a disclosure. Cold wallet UTXO selection is behind "Advanced" in Bitcoin Accounts.

**Anti-example:** Showing UTXO count, confirmation targets, and fee rate options on the main send screen.

**Governs:** Send flow, receive flow, wallet management, transaction detail.

### 4. Motion represents state

**Definition:** Every animation must communicate a specific state transition: processing, completion, risk, continuity, or confirmation. Motion that exists only to fill time or "look premium" is prohibited.

**Kerosene example:** The send button transitions from idle → processing (animated glyph) → success/failure (Rive state machine). The balance uses odometer animation only on real deltas, not on tab switch. Page transitions use 136ms easeOutQuart — fast enough to feel instant, slow enough to register direction.

**Anti-example:** Staggered list entry animations on every screen load. Elastic bounces on financial confirmations. Ambient animations that play regardless of state.

**Governs:** All screen transitions, button states, balance updates, payment status, error states.

### 5. Silent premium

**Definition:** Quality is communicated through precision, not decoration. Few effects. Intentional spacing. Strong typography. Deep surfaces. The existing Linear-inspired monochrome aesthetic is the entire brand voice.

**Kerosene example:** 5 surface levels stacked with 1px hairline borders. No drop shadows. Pill buttons (9999px) outlined in #F7F8F8, never filled. Playfair Display at custom half-step weights (w510/w590). 4pt grid rhythm. ~3% chromatic presence — gold (#D6A84F) as accent only.

**Anti-example:** Gradient CTAs. Glow effects on cards. Multiple accent colors. Drop shadows for elevation. Decorative iconography.

**Governs:** All visual surfaces. New component creation. Theme modifications.

### 6. Desktop is its own experience

**Definition:** The desktop interface must not be a phone layout centered in a wide window. It uses multi-column layouts, persistent side navigation, hover states, keyboard shortcuts, and content-constrained max-width where appropriate.

**Kerosene example:** Admin uses a persistent sidebar (240px expanded, 64px collapsed). Home on wide screens can show balance + activity side-by-side. All interactive elements have hover states on desktop.

**Anti-example:** A 390px-wide content column centered in a 1920px window. Bottom navigation on desktop. No hover states. No keyboard shortcuts for power users.

**Governs:** Responsive breakpoints, admin layout, home wide layout, navigation patterns.

---

## Decision matrix

| Situation | Principle | Decision |
|-----------|-----------|----------|
| New feature: where does it go on Home? | #1 Money before decoration | Below balance, above education. If financial, inside FinancialProjection. |
| Should we add a confirmation dialog? | #2 Security without anxiety | Only for destructive or high-value actions. Use inline confirmation for routine operations. |
| User asks for advanced fee control | #3 Progressive complexity | Add behind disclosure, not as default. Remember preference. |
| Screen transition feels abrupt | #4 Motion = state | Add pageIn/pageOut transition (136ms/92ms). Never add decorative stagger. |
| Designer proposes gradient button | #5 Silent premium | Reject. Use outlined pill button per DESIGN_SYSTEM.md. |
| Mobile layout looks empty on desktop | #6 Desktop is its own experience | Add side navigation, multi-column layout. Do not just center the mobile layout. |

---

## Token & file map

| Principle | Governs these files |
|-----------|-------------------|
| #1 Money before decoration | `lib/features/home/presentation/screens/home_screen_balance.dart`, `lib/features/home/presentation/widgets/animated_balance_display.dart` |
| #2 Security without anxiety | `lib/features/security/presentation/`, `lib/design_system/foundation/theme/monochrome_theme.dart` |
| #3 Progressive complexity | `lib/features/movement/presentation/send/`, `lib/features/financial_accounts/presentation/bitcoin_accounts_screen.dart` |
| #4 Motion = state | `lib/core/motion/app_motion.dart`, `lib/design_system/foundation/assets/animation/` |
| #5 Silent premium | `docs/DESIGN_SYSTEM.md`, `lib/design_system/foundation/theme/` |
| #6 Desktop is its own experience | `lib/core/responsive/kerosene_responsive.dart`, `lib/features/web_admin/` |

---

## Do / Don't

- [ ] DO place financial data at the top of the visual hierarchy
- [ ] DO use inline confirmation for routine operations, dialogs for destructive ones
- [ ] DO hide blockchain complexity behind progressive disclosure
- [ ] DO ensure every animation maps to a state transition
- [ ] DO use existing surface tokens and 1px borders for depth
- [ ] DO design desktop layouts with multi-column and side navigation
- [ ] DON'T let promotional or educational content dominate financial data
- [ ] DON'T use warning icons or fear language for normal operations
- [ ] DON'T expose UTXO selection, fee rate, or routing details on primary screens
- [ ] DON'T add animation that doesn't communicate a specific state change
- [ ] DON'T introduce new colors, radii, or effects outside the token system
- [ ] DON'T cap desktop layouts at phone width

---

## Verification

- [ ] Home screen: balance has greatest typographic weight?
- [ ] Security screens: calm, no red warnings for normal flows?
- [ ] Send flow: advanced options behind disclosure?
- [ ] Every animation maps to a state transition in the motion registry?
- [ ] No new colors/radii/spacing introduced in feature code?
- [ ] Desktop breakpoints render multi-column where appropriate?
