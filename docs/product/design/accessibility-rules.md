# Accessibility Rules

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

Financial interfaces handle other people's money. Inaccessible design isn't just poor UX — it excludes users from their own funds. Every Kerosene screen must be operable by users with visual, motor, or cognitive impairments.

---

## 1. Contrast

### Minimum ratios (WCAG AA)

| Element | Minimum ratio | Kerosene check |
|---------|--------------|----------------|
| Body text (< 18px) | 4.5:1 | #F7F8F8 on #08090A ≈ 18:1 PASS |
| Large text (≥ 18px or 24px) | 3:1 | PASS |
| UI components (borders, icons) | 3:1 | #F7F8F8 on #08090A PASS |
| Disabled text | No requirement | #7F7F80 on #141516 ≈ 4.5:1 PASS |

### Current palette verification
The Linear monochrome palette was designed with high contrast by nature:
- Primary text (#F7F8F8) on canvas (#08090A): ~18:1 — far exceeds AA and AAA
- Secondary text (#D0D6E0): ~11:1
- Tertiary text (#8A8F98): ~6:1
- Disabled text (#7F7F80): ~5:1 on Carbon

### Status colors on dark backgrounds
| Token | Color | On #08090A | On #141516 |
|-------|-------|-----------|-----------|
| Success green | Verify ratio ≥ 4.5:1 | — | — |
| Warning amber | Verify ratio ≥ 4.5:1 | — | — |
| Error red | Verify ratio ≥ 4.5:1 | — | — |

Any status color that fails contrast on its target surface must be lightened.

---

## 2. Touch targets

| Element | Minimum | Preferred |
|---------|---------|-----------|
| Standard interactive | 44 × 44pt | 48 × 48pt |
| Financial actions (send, confirm) | 48 × 48pt | 56 × 56pt |
| List rows (tappable) | 48pt height | 56-64pt height |
| Sidebar items | 44pt height | 48pt height |
| Checkboxes / toggles | 44 × 44pt | — |
| Icon buttons | 44 × 44pt | 48 × 48pt |

Spacing between touch targets: minimum 8pt to prevent mis-taps.

---

## 3. Semantics

### Screen reader labels

Every interactive element without visible text must have a `semanticLabel`:

```dart
// Required for icon-only buttons
KeroseneIcon(
  icon: KeroseneIcons.send,
  semanticLabel: 'Enviar dinheiro',
)

// Required for status indicators
Icon(
  Icons.circle,
  color: successGreen,
  semanticLabel: 'Transacao confirmada',
)
```

### Semantic hierarchy
- Each screen must have ONE header with `semanticsLabel: 'Cabecalho'`
- Financial amounts must include currency context: `semanticLabel: 'Saldo: R\$ 1.500,00'`
- Progress indicators: `semanticLabel: 'Processando pagamento, aguarde'`
- Images/icons without semantic meaning: `excludeFromSemantics: true`

### Announcements for live regions
Use `SemanticsService.announce()` for:
- Balance updates while screen is visible
- Transaction status changes
- Error states appearing
- "Live region" pattern for real-time financial data

---

## 4. Text scaling

### Requirements
- Support up to 200% text scale without layout breakage
- No text truncation at 150% scale (use `TextOverflow.ellipsis` as last resort)
- Line heights must scale proportionally
- Icons and touch targets do NOT scale with text

### Implementation
```dart
// Use MediaQuery.textScaleFactor for adaptive layouts
final scale = MediaQuery.of(context).textScaleFactor;

// Never clamp text scale factor — let the user decide
// Do NOT use:
// textScaleFactor: 1.0.clamp(...)
```

---

## 5. reduceMotion

### Detection
`KeroseneMotion.reduceMotion(context)` checks:
- `MediaQuery.disableAnimations`
- `MediaQuery.accessibleNavigation`

### Behavior when active
| Animation category | reduceMotion behavior |
|-------------------|----------------------|
| Functional | Collapse to `instant` (0ms) — state changes without transition |
| Continuity | Page transitions → `instant` |
| Brand | Still plays at accelerated speed (ceremonial confirmation IS semantic) |
| Ambient | Removed entirely — no glow, no displacement, no loops |
| Loading | Static indicator replaces animated spinner |

### Exceptions
- `Hero` transitions: still animate (essential for spatial understanding)
- Haptic feedback: unchanged (not visual)
- Scroll physics: unchanged (user-controlled)

---

## 6. Focus order (desktop)

### Logical tab sequence
1. Skip-to-content link (first focusable element)
2. Header / navigation
3. Main content (left→right, top→bottom inside each section)
4. Sidebar / secondary content
5. Footer

### Focus indicators
- Visible focus ring: 2px solid #F7F8F8 (Snow), offset 2px from element
- Never remove focus indicators (`FocusTraversalGroup` with `Visibility` is acceptable)
- Focus trap in modals and dialogs

---

## 7. Color independence

### Never rely on color alone
- Status indicators: icon + color + text label
- Chart data: patterns or labels in addition to color
- Links: underline + color (not color alone)
- Error states: icon + message + color

### Test: grayscale mode
Every screen must remain fully usable when rendered in grayscale.

---

## 8. Testing automation

### Flutter accessibility checks
```dart
// Widget test
await tester.pumpWidget(MyScreen());
await expectLater(tester, meetsGuideline(textContrastGuideline));
await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
await expectLater(tester, meetsGuideline(minimumTapTargetSizeGuideline));
```

### CI integration
- Accessibility checks run on every screen widget test
- Contrast validation for all token pairs
- Touch target audit on all interactive widgets
- New screens without semantic labels → CI fails

---

## Token & file map

| Concept | Source file |
|---------|------------|
| Motion reduceMotion | `lib/core/motion/app_motion.dart` |
| Haptics | `lib/design_system/foundation/interaction/kerosene_interaction.dart` |
| Icons | `lib/design_system/foundation/assets/icons/kerosene_icons.dart` |
| ARB translations | `lib/core/l10n/app_pt.arb` |

---

## Do / Don't

- [ ] DO ensure all text meets WCAG AA contrast minimums
- [ ] DO provide semanticLabel on every icon-only interactive element
- [ ] DO support text scaling up to 200%
- [ ] DO honor reduceMotion globally via KeroseneMotion
- [ ] DO provide visible focus indicators on desktop
- [ ] DO communicate state with icon + text + color (never color alone)
- [ ] DO test every screen in grayscale
- [ ] DON'T clamp text scale factor
- [ ] DON'T use color as the only differentiator for status
- [ ] DON'T remove focus indicators
- [ ] DON'T create touch targets smaller than 44pt

---

## Verification

- [ ] `flutter test test/accessibility/` passes?
- [ ] All screens render correctly at 200% text scale?
- [ ] All screens are usable in grayscale?
- [ ] All icon-only buttons have semanticLabel?
- [ ] `reduceMotion` removes ambient + collapses functional animations?
- [ ] Focus order is logical on desktop?
- [ ] All touch targets ≥44pt (48pt for financial)?
