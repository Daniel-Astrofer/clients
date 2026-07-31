# Visual Language

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

The design system defines the *values* of tokens (colors, spacing, typography). The visual language defines the *rules of composition* — how those tokens combine into surfaces, screens, and hierarchy. It answers: "Given these tokens, how should this screen look?"

---

## 1. Surface system

Kerosene creates depth without shadows. Five stacked gray surfaces separated by 1px hairline borders:

| Level | Name | Value | Purpose |
|-------|------|-------|---------|
| 0 | Onyx Canvas | `#08090A` | Page background, full-bleed base |
| 1 | Carbon | `#141516` | Input fields, inline code cards |
| 2 | Graphite | `#1C1C1F` | Nested panels, icon tiles |
| 3 | Smoke | `#23252A` | Hover surfaces, button borders |
| 4 | Iron | `#2D2E31` | Pressed/active state, highest elevation |

### Rules
- Each surface level adds ~8-12 luminance points — enough to register, not enough to distract
- Borders between surfaces: 1px solid Smoke (#23252A) or Ash (#34343A)
- Inner stroke: `rgba(255,255,255,0.03) 0px 0px 0px 1px inset` for elevated surfaces
- Never use `elevation` or `boxShadow` for depth
- The surface stack IS the depth system

---

## 2. Typography voice

### Font roles

| Role | Font | Weight | Usage |
|------|------|--------|-------|
| Display / hero | Playfair Display | w510 | Balance hero (48px), screen titles (32px), section headers (24px) |
| Body / UI | Plus Jakarta Sans | w400 | Descriptions (15px), labels, form content |
| Emphasis | Plus Jakarta Sans | w510 | Navigation items, button labels, section headers |
| Strong emphasis | Plus Jakarta Sans | w590 | Amounts, key values, inline emphasis |
| Technical | JetBrains Mono | w400 | Addresses, tx hashes, code references (13px) |

### Weight discipline
- w400: body text, descriptions, metadata
- w500: medium emphasis (rare, prefer w510)
- w510: headings, navigation, buttons — the signature display weight
- w590: emphasis, amounts — half-step past medium for controlled weight
- NEVER: w600, w700 (reads as generic bold)

### Scale
| Role | Size | Line height | Letter spacing |
|------|------|-------------|----------------|
| Caption | 12px | 1.6 | -0.12px |
| Body | 15px | 1.5 | -0.15px |
| Heading-sm | 24px | 1.33 | -0.288px |
| Heading | 32px | 1.2 | -0.416px |
| Display | 48px | 1.13 | -1.056px |

All sizes use negative tracking — tighter letterspacing at larger sizes reinforces the "machined precision" character.

---

## 3. Geometry

### Radii — only three values
| Radius | Value | Usage |
|--------|-------|-------|
| Input | 4px | Text fields, code blocks, inline elements |
| Card | 8px | Cards, panels, dialogs, surfaces with content |
| Pill | 9999px | Action buttons, navigation pills, tag chips |

Never introduce intermediate radii (6px, 12px, 16px). These three are the entire geometry language.

### Spacing — 4pt grid
Base unit: 4px. All spacing values are multiples of 4.

| Semantic | Value | Usage |
|----------|-------|-------|
| Element gap | 8px | Between related elements inside a surface |
| Inline padding | 12px | Horizontal padding inside inputs and pills |
| Standard gap | 16px | Between independent elements |
| Section gap | 32px | Between surface groups |
| Module gap | 48px | Between major sections |

---

## 4. Color discipline — ~3% chromatic presence

### Monochrome (97% of the interface)
The 14 monochrome tokens from DESIGN_SYSTEM.md handle nearly everything.

### Chromatic accents (3%)
| Token | Value | Usage |
|-------|-------|-------|
| Brand | `#D6A84F` (gold) | ONE accent per screen max — logo, selected state, key indicator |
| Success | Green | Confirmed transaction, received payment |
| Warning | Amber | Pending, unconfirmed, syncing |
| Error | Red | Failed, insufficient funds, network error |
| Bitcoin | `#F59E0B` (orange) | Bitcoin-specific indicators only |

### Rules
- A screen should have at most ONE chromatic accent at a time
- Status colors appear only when that status is active
- Never use brand gold as a background fill — it is an accent, not a surface
- The interface should feel monochrome at a glance; color appears only where it carries meaning

---

## 5. Composition rules

### Information hierarchy
1. **Primary data** — Balance, amount, status. Playfair Display. w510 or w590. Color #F7F8F8 (Snow). Largest type on screen.
2. **Secondary context** — Wallet name, counterparty, fee. Plus Jakarta Sans. w400. Color #D0D6E0 (Mist).
3. **Tertiary metadata** — Timestamps, tx IDs, confirmation count. w400 at 12-13px. Color #8A8F98 (Fog) or #62666D (Steel).
4. **Actions** — Pill buttons (9999px). 1px #F7F8F8 border. w510. Color #F7F8F8.

### Screen density
- Mobile: one primary surface filling ~60% of viewport height, secondary content scrollable below
- Desktop: primary surface anchored top-left, secondary in adjacent column or below
- Lists: 56-64px row height for transaction rows; 48px for settings rows
- Never: content floating in excessive whitespace (the "phone centered in desktop" anti-pattern)

### Dominant action placement
- Mobile: bottom-anchored or immediately below the primary data
- Desktop: right-aligned within the content column, or persistent in toolbar
- Never: floating action buttons (FAB) — use pill buttons inline

---

## Token & file map

| Rule | Source file |
|------|------------|
| Surface levels | `lib/design_system/foundation/theme/kerosene_brand_tokens.dart` |
| Typography | `lib/design_system/foundation/theme/app_typography.dart` |
| Spacing | `lib/design_system/foundation/theme/app_spacing.dart` |
| Colors | `lib/design_system/foundation/theme/app_colors.dart` |
| Radii | `lib/design_system/foundation/theme/app_theme.dart` (`AppRadius`) |
| Component themes | `docs/DESIGN_SYSTEM.md` §4 |

---

## Do / Don't

- [ ] DO use surface levels (Onyx→Carbon→Graphite) for depth, never shadows
- [ ] DO use Playfair Display for financial hierarchy, Plus Jakarta Sans for body
- [ ] DO use only w400, w500, w510, w590; never w600 or w700
- [ ] DO use only 4px, 8px, 9999px radii
- [ ] DO use 4pt-grid spacing values
- [ ] DO limit chromatic color to ~3% of the interface
- [ ] DO place the dominant action using the pill button signature
- [ ] DON'T use drop shadows or elevation for depth
- [ ] DON'T introduce intermediate radii or spacing values
- [ ] DON'T fill buttons with solid backgrounds
- [ ] DON'T use brand gold as a surface fill
- [ ] DON'T float content in excessive whitespace on desktop

---

## Verification

- [ ] All surfaces use the 5-level stack, no boxShadow?
- [ ] All text uses allowed weights (w400/w500/w510/w590), no w600/w700?
- [ ] All radii are 4px, 8px, or 9999px?
- [ ] All spacing values are multiples of 4?
- [ ] Chromatic accents appear only for status/meaning, <3% of pixels?
- [ ] Primary actions use outlined pill buttons?
