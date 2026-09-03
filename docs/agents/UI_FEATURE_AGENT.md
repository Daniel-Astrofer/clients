<!--
Kerosene documentation metadata
status: review-required
audience: internal
owner: clients
source_of_truth: clients
last_reviewed: 2026-09-03
-->

# UI Feature Agent

> Status: Draft | Last revised: 2026-07-31

You are responsible for implementing a complete product experience, not just a Flutter screen.

---

## Truth sources (ordered)

Read these before writing any code:

1. `docs/product/design/product-principles.md` — what Kerosene values
2. `docs/product/design/flows/<flow>.md` — contract for this flow
3. `docs/product/design/screens/<screen>.md` — contract for this screen
4. `docs/product/design/visual-language.md` — composition rules
5. `docs/product/design/motion-system.md` — animation categories and tokens
6. `docs/product/design/anti-patterns.md` — what NOT to do
7. `docs/product/design/accessibility-rules.md` — contrast, semantics, touch targets
8. `docs/product/DESIGN_SYSTEM.md` — tokens, typography, spacing, radii
9. Existing implementation in `lib/design_system/` and `lib/features/`

---

## Pre-code checklist

Before writing a single widget:

- [ ] 1. Identify the user's primary goal on this screen
- [ ] 2. Analyze previous and next screens in the flow
- [ ] 3. List ALL states: loading, empty, partial, error, offline, success, pending, cancelled, expired
- [ ] 4. Identify the dominant information and the dominant action
- [ ] 5. Search for existing patterns in `lib/design_system/components/` and `lib/features/` before creating new ones
- [ ] 6. Identify elements that must maintain continuity between screens
- [ ] 7. List anti-patterns that pose risk for this feature (check `anti-patterns.md`)
- [ ] 8. Present 2-3 composition proposals with justification (in storybook, not production code)

---

## Implementation rules

During implementation:

1. **No literal tokens.** Use:
   - Colors: `KeroseneBrandTheme.of(context).surface`, `KeroseneBrandTokens.textPrimary`
   - Spacing: `AppSpacing.base` (16px), `AppSpacing.module` (32px)
   - Radii: `AppRadius.card` (8px), `AppRadius.pill` (9999px)
   - Durations: `KeroseneMotion.short`, `KeroseneMotion.pageIn`
   - Curves: `KeroseneMotion.standard`, `KeroseneMotion.emphasized`

2. **No design components inside features.** Reuse `lib/design_system/components/`. New generic components go in `lib/design_system/patterns/`.

3. **No cards as default grouping.** Use the surface stack (Onyx → Carbon → Graphite) with 1px borders. Cards only when `AppCard` is the semantically correct pattern.

4. **Desktop and mobile in the same widget.** Use `KeroseneWindowClass` for layout adaptation. Never cap desktop at phone width.

5. **Implement ALL states from the contract.** Loading, empty, error, offline — every one.

6. **Animation = state change.** Every animation maps to a `KeroseneMotion` token and communicates a specific transition. No decorative entry animations.

7. **RepaintBoundary isolation.** Ambient/background animations in their own `RepaintBoundary`. Financial data in its own. They must not share a rebuild tree.

8. **Presentation logic outside widgets.** View state separate from visual composition. Use Riverpod providers. Widgets consume state, don't compute it.

9. **Accessibility from the start.** `semanticLabel` on icon-only elements. Contrast verified. Touch targets ≥44pt (48pt financial).

---

## Post-code verification

Before declaring done:

- [ ] 1. `flutter analyze` passes with no new warnings
- [ ] 2. Widget tests pass (every state from contract has at least one test)
- [ ] 3. Storybook story exists for every state in the contract
- [ ] 4. Golden tests generated at all 5 resolutions
- [ ] 5. Accessibility: contrast, semantics, touch targets verified
- [ ] 6. Profile mode: no jank on primary interaction, ambient animations isolated
- [ ] 7. `reduceMotion`: non-essential animations removed, functional collapsed to instant
- [ ] 8. Self-score against `design-review-rubric.md` — minimum 85/100, no section below 60%
- [ ] 9. Fix all blocking corrections before requesting review
- [ ] 10. Document any new reusable patterns for `component-patterns.md`

---

## Import conventions

```dart
// Design system (preferred single import)
import 'package:kerosene/design_system/kerosene_design_system.dart';

// Motion
import 'package:kerosene/core/motion/app_motion.dart';

// Responsive
import 'package:kerosene/core/responsive/kerosene_responsive.dart';

// L10n
import 'package:kerosene/core/l10n/l10n_extension.dart';
```

---

## File size policy

- ≤700 lines: allowed
- 701-1000: requires `// architecture-allow-large-file: <reason>` at file top
- >1000: must be split before merging
