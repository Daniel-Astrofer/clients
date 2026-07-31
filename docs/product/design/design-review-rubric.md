# Design Review Rubric

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

"Looks good" is not a review. Agents need objective, measurable criteria to evaluate their own output. This rubric turns visual quality into a numerical score that can be compared, tracked, and enforced. A screen that compiles but scores below 85 is not done.

---

## Scoring

**Total: 100 points**
**Minimum passing: 85/100**
**Minimum per section: 60% of section points (no section can be near-zero)**

---

## Section 1: Flow & Comprehension (25 points)

The user must understand the screen immediately.

| Criterion | Points | Check |
|-----------|--------|-------|
| Screen goal immediately clear | 7 | Can a new user state what this screen does within 3 seconds? |
| Dominant action obvious | 7 | Is there exactly ONE primary CTA, visually dominant? |
| Next step predictable | 6 | After the dominant action, does the user know what will happen? |
| All states coherent | 5 | Loading, empty, error, success all maintain the same layout structure? |

**60% floor (15/25)**: At minimum, the screen goal must be identifiable and there must be a dominant action. Missing states or unpredictable flow drop below 15.

---

## Section 2: Visual Hierarchy (20 points)

Information must be weighted correctly.

| Criterion | Points | Check |
|-----------|--------|-------|
| Most important info has greatest weight | 8 | Balance/amount uses largest type, strongest weight (w590)? |
| No competing elements | 6 | Are there multiple elements fighting for attention at the same weight? |
| Reading effortless | 6 | Can the eye flow top→bottom without jumping? Are groups visually distinct? |

**60% floor (12/20)**: The primary data must be typographically dominant. Some competition is acceptable if hierarchy is still clear.

---

## Section 3: Product Coherence (15 points)

The screen must feel like Kerosene, not a generic app.

| Criterion | Points | Check |
|-----------|--------|-------|
| Reuses Kerosene patterns | 5 | Uses existing components/patterns, not invented widgets? |
| Feels like same app | 5 | Would a user recognize this as Kerosene? Same monochrome, same typography, same pills? |
| No local styles | 5 | Zero raw `Color(...)`, `BorderRadius`, `EdgeInsets`, `Duration` in feature code? |

**60% floor (9/15)**: Must use tokens for colors and at least one canonical Kerosene pattern. No local hex colors.

---

## Section 4: Motion (15 points)

Animation must communicate state.

| Criterion | Points | Check |
|-----------|--------|-------|
| Animation communicates state | 5 | Every animation maps to a specific state transition (functional, continuity, brand, ambient)? |
| Continuity preserved | 4 | Elements that persist between screens maintain perceptual position? |
| Interruptible / reversible | 3 | Can the user interrupt or go back mid-animation? |
| reduceMotion supported | 3 | All animations respect `KeroseneMotion.reduceMotion(context)`? |

**60% floor (9/15)**: At minimum, animations must use `KeroseneMotion` tokens (not raw durations) and respond to `reduceMotion`. Continuity is ideal but not required for 60%.

---

## Section 5: States & Resilience (10 points)

Every state must be implemented.

| Criterion | Points | Check |
|-----------|--------|-------|
| All states implemented | 6 | Loading, empty, error, offline, success, partial data — all present? |
| Update preserves context | 4 | On refresh/data change, does the user keep their scroll position, selected item, input? |

**60% floor (6/10)**: Loading, error, and success states must be present. Empty and offline are bonus. Context preservation is bonus.

---

## Section 6: Accessibility (10 points)

Must be usable by everyone.

| Criterion | Points | Check |
|-----------|--------|-------|
| Contrast meets WCAG AA | 3 | Text ≥ 4.5:1, large text ≥ 3:1? |
| Semantic labels present | 3 | Icon buttons have `semanticLabel`? Financial amounts announced with context? |
| Touch targets ≥44pt (48pt financial) | 2 | All interactive elements meet minimum? |
| Text scaling to 200% | 2 | Layout doesn't break at 2x text scale? |

**60% floor (6/10)**: Contrast and semantic labels are non-negotiable. Touch targets and text scaling can be partial for 60%.

---

## Section 7: Performance (5 points)

No jank, efficient rendering.

| Criterion | Points | Check |
|-----------|--------|-------|
| No perceptible jank | 3 | Screen renders at 60fps in profile mode? No dropped frames on primary interaction? |
| Rebuilds isolated | 2 | Ambient animations isolated by `RepaintBoundary`? Financial data not rebuilt by decorative animations? |

**60% floor (3/5)**: Must pass 60fps on primary interaction in profile mode. Rebuild isolation is bonus.

---

## Scoring template

```markdown
## Review: [Screen Name] — [Date]

### Section 1: Flow & Comprehension ( /25)
- Screen goal clear: [Y/N] ( /7)
- Dominant action obvious: [Y/N] ( /7)
- Next step predictable: [Y/N] ( /6)
- States coherent: [Y/N] ( /5)

### Section 2: Visual Hierarchy ( /20)
- Info weighted correctly: [Y/N] ( /8)
- No competing elements: [Y/N] ( /6)
- Reading effortless: [Y/N] ( /6)

### Section 3: Product Coherence ( /15)
- Reuses patterns: [Y/N] ( /5)
- Feels like Kerosene: [Y/N] ( /5)
- No local styles: [Y/N] ( /5)

### Section 4: Motion ( /15)
- Communicates state: [Y/N] ( /5)
- Continuity: [Y/N] ( /4)
- Interruptible: [Y/N] ( /3)
- reduceMotion: [Y/N] ( /3)

### Section 5: States & Resilience ( /10)
- All states: [Y/N] ( /6)
- Context preserved: [Y/N] ( /4)

### Section 6: Accessibility ( /10)
- Contrast: [Y/N] ( /3)
- Semantics: [Y/N] ( /3)
- Touch targets: [Y/N] ( /2)
- Text scaling: [Y/N] ( /2)

### Section 7: Performance ( /5)
- No jank: [Y/N] ( /3)
- Rebuilds isolated: [Y/N] ( /2)

### Total: __ / 100
### Result: [PASS (≥85) / FAIL]
### Sections below 60%: [list]
```

---

## Correction workflow

1. Visual Critic scores the screen
2. Items scoring 0 are reported as **blocking corrections**
3. Items scoring partial are reported as **improvements**
4. Implementer fixes blocking corrections first
5. Re-score. Repeat until ≥85 and no section below 60%.

---

## Baseline scores (to be calibrated in Phase 3)

| Screen | Score | Date | Notes |
|--------|-------|------|-------|
| Home | TBD | — | Baseline reference |
| Send Review | TBD | — | Baseline reference |
| Admin Dashboard | TBD | — | Baseline reference |

---

## Do / Don't

- [ ] DO score every new screen against this rubric before merging
- [ ] DO require ≥85 points and no section below 60%
- [ ] DO fix blocking corrections before improvements
- [ ] DO re-score after each round of fixes
- [ ] DON'T skip sections that "don't apply" — every section applies to every screen
- [ ] DON'T accept "it compiles" as done — the rubric is the real gate
- [ ] DON'T merge screens that score below 85

---

## Verification

- [ ] Rubric applied to 3 existing screens for baseline calibration?
- [ ] Every new screen PR includes a completed rubric in the description?
- [ ] CI or review checklist enforces rubric completion?
