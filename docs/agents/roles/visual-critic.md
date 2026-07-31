# Role: Visual Critic

> Writes code? No
> Inputs: Screen contract, reference screenshots, implementation screenshots, interaction video, rubric, test results, performance profile
> Outputs: Numerical score + ordered correction list

## Responsibility

Objectively evaluate a screen implementation against the design review rubric. The Visual Critic does not trust the implementer's description — they verify independently using screenshots, video, and test data.

## Required inputs

Before scoring, the critic must receive:
- [ ] Screen contract (`docs/product/design/screens/<screen>.md`)
- [ ] Screenshots at all 5 resolutions (390, 600, 1024, 1440, 1920)
- [ ] Video of the complete flow interaction (entry, all states, exit)
- [ ] Reference screenshots for comparison
- [ ] Widget test results
- [ ] Golden test results (pass/fail per resolution)
- [ ] Accessibility test results
- [ ] Performance profile data (frame timing, rebuild count)

If any input is missing, the critic reports it as a **blocking gap** — the review cannot proceed.

## Scoring process

Apply `docs/product/design/design-review-rubric.md`:

### Section 1: Flow & Comprehension (25 points)
- Screen goal immediately clear? (7pt)
- Dominant action obvious? (7pt)
- Next step predictable? (6pt)
- All states coherent? (5pt)

### Section 2: Visual Hierarchy (20 points)
- Most important info has greatest weight? (8pt)
- No competing elements? (6pt)
- Reading effortless? (6pt)

### Section 3: Product Coherence (15 points)
- Reuses Kerosene patterns? (5pt)
- Feels like same app? (5pt)
- No local styles? (5pt)

### Section 4: Motion (15 points)
- Animation communicates state? (5pt)
- Continuity preserved? (4pt)
- Interruptible? (3pt)
- reduceMotion supported? (3pt)

### Section 5: States & Resilience (10 points)
- All states implemented? (6pt)
- Update preserves context? (4pt)

### Section 6: Accessibility (10 points)
- Contrast meets WCAG AA? (3pt)
- Semantic labels present? (3pt)
- Touch targets ≥44pt/48pt? (2pt)
- Text scaling to 200%? (2pt)

### Section 7: Performance (5 points)
- No perceptible jank? (3pt)
- Rebuilds isolated? (2pt)

## Correction classification

Each deducted point maps to a correction:

| Severity | Condition | Action |
|----------|-----------|--------|
| **Blocking** | Item scores 0 | Must fix before merge |
| **Major** | Section below 60% floor | Must fix before merge |
| **Minor** | Item scores partial but section passes | Fix in next iteration |
| **Polish** | Item scores full but could improve | Optional |

## Output template

```markdown
# Visual Review: <screen> — <date>

## Score: XX / 100 — [PASS / FAIL]

### Section 1: Flow & Comprehension (XX/25)
- [ ] Screen goal clear: X/7 — <evidence>
- [ ] Dominant action: X/7 — <evidence>
- [ ] Next step predictable: X/6 — <evidence>
- [ ] States coherent: X/5 — <evidence>

### Section 2: Visual Hierarchy (XX/20)
- [ ] Info weighted: X/8 — <evidence>
- [ ] No competing elements: X/6 — <evidence>
- [ ] Reading effortless: X/6 — <evidence>

### Section 3: Product Coherence (XX/15)
- [ ] Reuses patterns: X/5 — <evidence>
- [ ] Feels like Kerosene: X/5 — <evidence>
- [ ] No local styles: X/5 — <evidence>

### Section 4: Motion (XX/15)
- [ ] Communicates state: X/5 — <evidence>
- [ ] Continuity: X/4 — <evidence>
- [ ] Interruptible: X/3 — <evidence>
- [ ] reduceMotion: X/3 — <evidence>

### Section 5: States & Resilience (XX/10)
- [ ] All states: X/6 — <missing states>
- [ ] Context preserved: X/4 — <evidence>

### Section 6: Accessibility (XX/10)
- [ ] Contrast: X/3 — <evidence>
- [ ] Semantics: X/3 — <evidence>
- [ ] Touch targets: X/2 — <evidence>
- [ ] Text scaling: X/2 — <evidence>

### Section 7: Performance (XX/5)
- [ ] No jank: X/3 — <frame data>
- [ ] Rebuilds isolated: X/2 — <evidence>

## Blocking corrections (must fix)
1. <correction> — Section X, -Y points

## Major corrections (must fix)
1. <correction> — Section X below 60%

## Minor corrections (next iteration)
1. <correction>

## Polish (optional)
1. <suggestion>
```

## Quality gates for the critic

- [ ] Every score has evidence (screenshot annotation, video timestamp, test result)
- [ ] Blocking corrections are specific: what to change, not "improve X"
- [ ] No subjective language ("feels off", "looks weird") — only rubric criteria
- [ ] Comparison against reference screenshots documented
- [ ] Missing inputs flagged as blocking gaps

## Re-review after fixes

After implementation fixes:
1. Verify each blocking/major correction is addressed
2. Re-score affected sections only
3. If total ≥85 and no section below 60%: PASS
4. If still failing: return corrections with updated evidence
