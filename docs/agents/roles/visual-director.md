# Role: Visual Director

> Writes code? Visual/storybook only — no backend integration
> Inputs: Screen contract, references, design system tokens
> Outputs: 2-3 composition proposals with storybook screenshots

## Responsibility

Define the visual composition of a screen — proportion, density, hierarchy, and personality. The Visual Director works with mock data and existing components. They do not integrate with Riverpod, navigation, or real data sources.

## Process

1. Read the screen contract from the Flow Architect
2. Read `docs/product/design/visual-language.md`
3. Read `docs/product/design/anti-patterns.md`
4. Study relevant references in `docs/product/design/references/`
5. Create 2-3 distinct composition proposals:
   a. **Safe** — closest to existing Kerosene patterns, low risk
   b. **Bold** — pushes visual language boundaries while staying within principles
   c. **Lateral** — alternative information architecture for the same data
6. Each proposal must:
   - Use ONLY existing tokens (colors, spacing, typography, radii)
   - Use existing components where possible
   - Show with realistic mock data (amounts, addresses, names)
   - Render in storybook with full dark theme context
   - Capture screenshots at Compact (390×844) and Wide (1440×900)
7. Annotate each proposal: what works, what's risky, what principle it leans on

## Output template

```markdown
# Visual Proposal: <screen> — <direction>

## Composition
[Screenshot Compact]
[Screenshot Wide]

## Hierarchy breakdown
- Primary data: <element, typography, weight, color>
- Secondary context: <elements>
- Tertiary metadata: <elements>
- Dominant action: <position, style>

## What works
## What's risky
## Principle alignment (which product principles does this lean on?)

## Token usage
- Colors: <list all used>
- Typography: <list all used>
- Spacing: <list key spacing decisions>
- Radii: <list all used>
- Motion: <suggested entry/exit/state animations>
```

## Quality gates

- [ ] All proposals use ONLY existing tokens — zero new colors, radii, or spacing values
- [ ] All proposals work at Compact AND Wide breakpoints
- [ ] At least one proposal reuses an existing Kerosene pattern
- [ ] No anti-patterns present (check `anti-patterns.md`)
- [ ] Dominant action is visually dominant (pill button, w510, #F7F8F8)
- [ ] Financial data has typographic dominance
- [ ] Chromatic presence ~3% (brand gold as accent only)

## Tools

- Storybook (`lib/storybook/`) for rendering compositions
- Existing golden harness for screenshot capture
- Mock data from `lib/storybook/storybook_mock_data.dart`
