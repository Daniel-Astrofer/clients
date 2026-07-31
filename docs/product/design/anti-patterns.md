# Anti-Patterns

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

AI agents default to statistically common UI patterns: cards with icons in circles, gradient backgrounds, staggered list animations, skeleton loaders. These patterns are generic — they don't reflect Kerosene's design language. This document tells agents what NOT to do, with explicit alternatives.

---

## Prohibited patterns

### 1. Card collections without hierarchy

**What:** A screen composed of 3-6 independent cards, all at the same visual weight, each with icon + title + subtitle + action.

**Why prohibited:** Creates visual noise. The user can't distinguish what matters. Violates "Money before decoration."

**Use instead:** One dominant surface for the primary financial data, secondary information in a structured list below. Use surface levels (Carbon → Graphite → Smoke) to create hierarchy without cards.

**Kerosene example:** Home has one financial projection area (balance + wallet selector) at the top, then activity rows below. Not 5 equal-weight cards.

---

### 2. Decorative gradients

**What:** Gradient backgrounds on cards, buttons, or headers to "look premium."

**Why prohibited:** Violates "Silent premium." The Kerosene aesthetic achieves depth through stacked monochrome surfaces and 1px borders, not color transitions. Gradients are reserved for atmosphere shaders (aurora, gemini glow) which are server-driven and semantically meaningful.

**Use instead:** Stacked surface levels (Onyx → Carbon → Graphite). Hairline borders (1px, Ash/Ferrite).

**Exception:** `HomeAuroraBackground` and `GeminiGlowBackground` — fragment shader-based atmosphere that reacts to scroll. These are the ONLY gradient surfaces.

---

### 3. Icon inside a circle for every action

**What:** Every action button is an icon wrapped in a circular container with a background.

**Why prohibited:** Generic. Adds visual weight to secondary actions. The Kerosene pill button is the action signature, not the icon circle.

**Use instead:** Primary action: outlined pill button (9999px, 1px #F7F8F8 border). Secondary actions: bare icons or text-only at w510. Icon circles only when the icon IS the primary content (e.g., wallet type badge).

---

### 4. One button for every available piece of information

**What:** A screen showing 5 pieces of data, each with its own action button.

**Why prohibited:** Violates "Progressive complexity" and creates decision fatigue. Every screen must have ONE dominant action.

**Use instead:** Identify the dominant action. Secondary actions become tappable rows, disclosure triggers, or context menu items — not competing buttons.

---

### 5. Title, subtitle, and body repeating the same information

**What:** A card with "Balance," a subtitle "Your current balance," and a body "R$ 1.500,00."

**Why prohibited:** Redundant. Wastes vertical space. Violates "Silent premium" — precision means every element carries unique information.

**Use instead:** Label + value. If the label is self-evident (balance, send, receive), omit it entirely. Use typographic weight (w590) and color shift (#F7F8F8) to distinguish values from context.

---

### 6. Glassmorphism in long lists

**What:** Blur-behind effects on list items (transaction rows, wallet list).

**Why prohibited:** Performance disaster at scale. Blur-per-item in a 50-item list destroys frame budget. Violates the performance budget.

**Use instead:** Solid surface (Carbon #141516) for list items. 1px dividers (Smoke #23252A). Glass/blur reserved for modal overlays and the home atmosphere layer only.

---

### 7. Desktop layout capped at phone width

**What:** A 390px-wide content column centered in a 1920px window.

**Why prohibited:** Violates "Desktop is its own experience." Wastes screen real estate. Feels like a port, not a product.

**Use instead:** Use `KeroseneResponsiveMetrics` breakpoints. Multi-column at ≥ Medium (600pt). Sidebar navigation at ≥ Expanded (960pt). Content-constrained max-width (~1200px) for readability on Ultra-wide.

---

### 8. All components animating on screen entry

**What:** Staggered fade-slide-up on every widget when a screen appears (`flutter_animate` `.animate().fadeIn().slideY()` on entire column children).

**Why prohibited:** Violates "Motion represents state." Entry animations that play on every navigation become noise. The user stops perceiving them as meaningful.

**Use instead:** Animate only state changes (button → processing, balance update, page transition). The screen itself can use `pageIn`/`pageOut` transitions. Individual widgets inside the screen should NOT animate on entry unless their presence IS the state change (e.g., error banner appearing).

---

### 9. Skeleton loaders when silent update preserves continuity better

**What:** Replacing content with gray rectangles (skeleton) on every data refresh.

**Why prohibited:** Destroys continuity. The user sees their balance disappear and reappear on every pull-to-refresh. This is jarring in a financial context.

**Use instead:** Preserve previous state. Show the last-known balance with a subtle sync indicator. Update in place when new data arrives. Use skeleton ONLY for first load (no previous state exists).

**Kerosene example:** Home preserves the last balance during refresh. The odometer ceremony plays only on first appearance and real deltas.

---

### 10. Local colors, radii, spacing, or durations

**What:** `Color(0xFF1A1B1C)`, `BorderRadius.circular(12)`, `EdgeInsets.only(top: 18)`, `Duration(milliseconds: 350)` written directly in feature code.

**Why prohibited:** Bypasses the token system. Changes to design language require sweeping search-and-replace. Inconsistent with the rest of the product.

**Use instead:**
- Colors: `KeroseneBrandTheme.of(context).surface`, `KeroseneBrandTokens.textPrimary`
- Radii: `AppRadius.card` (8px), `AppRadius.input` (4px), `AppRadius.pill` (9999px)
- Spacing: `AppSpacing.base` (16px), `AppSpacing.module` (32px)
- Durations: `KeroseneMotion.short`, `KeroseneMotion.pageIn`
- Curves: `KeroseneMotion.standard`, `KeroseneMotion.emphasized`

**Exception:** Scene renderers (aurora, glow, atmosphere) — their values are visual design, not tokens.

---

### 11. Elastic animation in serious financial contexts

**What:** `Curves.elasticOut`, `Curves.easeOutBack`, or spring physics on financial confirmations, balance displays, or transaction status.

**Why prohibited:** Playful physics contradict the serious nature of financial operations. A balance settling with a bounce feels unreliable.

**Use instead:** `KeroseneMotion.standard` (easeOutCubic) or `KeroseneMotion.emphasized` (easeOutExpo) for financial transitions. Reserve `KeroseneMotion.spring` for non-financial moments (onboarding, education, atmosphere).

---

### 12. Error states as dismissible SnackBars

**What:** `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error')))` for operation failures.

**Why prohibited:** Disappears automatically. Does not explain what happened or what to do. Inaccessible to screen readers after dismissal.

**Use instead:** Inline `StateFeedbackView` with error variant. Shows: what happened, why, and what action to take. Persistent until user acts. Survives navigation.

---

### 13. w600 or w700 font weights

**What:** `FontWeight.w600` or `FontWeight.w700` in any UI text.

**Why prohibited:** Kerosene's typographic voice uses half-step weights: w400, w500, w510, w590 (see DESIGN_SYSTEM.md §2.2). Standard weights 600/700 are too heavy and read as "generic bold."

**Use instead:** w510 for headings/navigation/buttons. w590 for emphasis/amounts. Never w600 or w700.

---

### 14. Filled buttons with solid backgrounds

**What:** A button with a solid color fill (`color: KeroseneBrandTokens.brand`, filled background).

**Why prohibited:** The Kerosene button signature is the outlined pill: transparent background, 1px #F7F8F8 border, 9999px radius. Filled buttons read as a different design language.

**Use instead:** `AppButton` (primary outlined pill). Ghost variant for secondary actions. Never fill the button background.

---

## Quick reference: What to use instead

| Anti-pattern | Use instead |
|-------------|------------|
| Cards without hierarchy | One dominant surface + structured list |
| Decorative gradients | Monochrome surface stack + 1px borders |
| Icon-in-circle | Bare icon or pill button |
| Button per info item | One dominant action + tappable rows |
| Title/subtitle/body repetition | Label + value, weight + color shift |
| Glassmorphism in lists | Solid surfaces + dividers |
| Phone-width desktop | Responsive breakpoints + multi-column |
| Staggered entry animations | Animate state changes only |
| Skeleton on refresh | Preserve state + subtle sync indicator |
| Local colors/radii/spacing | Semantic tokens only |
| Elastic animation (financial) | easeOutCubic / easeOutExpo |
| Error as SnackBar | Persistent StateFeedbackView |
| w600/w700 weights | w510 / w590 |
| Filled buttons | Outlined pill buttons |
