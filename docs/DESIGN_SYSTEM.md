# Kerosene Design System (Linear-inspired)

> Deep-space monochrome. Machined precision. Confidence from contrast and restraint, not from accents.

## Design Philosophy

Linear operates in a deep-space monochrome: a near-black canvas (#08090a) layered with whisper-quiet neutral surfaces, hairline borders at 4-5px radius, and almost no chromatic presence. The entire interface reads as machined precision — Inter Variable at custom weights (400, 500, 510, 590) with negative tracking, and Berkeley Mono reserved for inline code references. Elevation is implied by stacked grays and 1px strokes, never by drop shadows. Buttons are pill-shaped (9999px) outlined in white, never filled with brand color. The result feels like an engineering control surface: dense, calm, and information-first.

## File Map

| File | Role |
|------|------|
| `design_system/foundation/theme/app_colors.dart` | Core color tokens + compatibility hex constants |
| `design_system/foundation/theme/app_typography.dart` | Typography scale (only layer allowed to call `GoogleFonts`) |
| `design_system/foundation/theme/app_spacing.dart` | 4pt grid spacing system |
| `design_system/foundation/theme/app_theme.dart` | `ThemeData` (dark/light) + `ThemeExtension` for `AppThemePalette` |
| `design_system/foundation/theme/kerosene_brand_tokens.dart` | Brand semantic tokens (surface, border, text, status) |
| `design_system/foundation/theme/monochrome_theme.dart` | Monochrome `ThemeExtension` for security/PIN screens |
| `design_system/foundation/theme/home_surface_tokens.dart` | Home screen surface tokens |
| `design_system/foundation/theme/send_flow_theme.dart` | Send/receive wizard tokens |
| `design_system/foundation/theme/theme_token_bridge.dart` | `isLight` bridge for code not yet refactored |

## 1. Color System

### 1.1 Monochrome Palette (Dark Mode)

All 14 tokens from the Linear style guide live as `static const` in `AppColors`:

| Name | Value | `AppColors` constant | Role |
|------|-------|---------------------|------|
| Onyx Canvas | `#08090a` | — | Page background, primary surface |
| Carbon Surface | `#141516` | — | Elevated card, input field, subtle surface layer |
| Graphite Surface | `#1c1c1f` | — | Mid-elevation panels, nested surfaces |
| Smoke Surface | `#23252a` | — | Hover state, deeper card, button surface tone |
| Iron Surface | `#2d2e31` | — | Pressed/active surface, highest tier elevation |
| Ash Border | `#34343a` | — | Primary hairline border |
| Ferrite Border | `#3e3e44` | `ferriteBorder` | Inner shadow stroke, focus-adjacent borders |
| Steel Text | `#62666d` | — | Tertiary text, muted icon state |
| Pewter Text | `#7f7f80` | — | Disabled text, placeholder |
| Fog Text | `#8a8f98` | — | Muted body, metadata, timestamps |
| Mist Text | `#d0d6e0` | — | Secondary text, descriptions |
| Chalk Border | `#e4e5e9` | — | Light icon accent, rare light dividers |
| Snow | `#f7f8f8` | — | Primary text, headings, pill border — the only near-white |
| Void | `#030404` | — | Deepest recess, absolute dark accent |

### 1.2 Surface Levels (Dark)

| Level | Name | Value | Purpose |
|-------|------|-------|---------|
| 0 | Onyx Canvas | `#08090a` | Page background, full-bleed base |
| 1 | Carbon | `#141516` | Input fields, inline code cards |
| 2 | Graphite | `#1c1c1f` | Nested panels, icon tiles, code snippets |
| 3 | Smoke | `#23252a` | Borders, hover surfaces, button borders |
| 4 | Iron | `#2d2e31` | Pressed/active state, highest elevation |

### 1.3 Brand Token API

Use `KeroseneBrandTokens` / `KeroseneBrandTheme` for semantic access:

```dart
// Surface hierarchy (context-aware via Theme.of(context)):
KeroseneBrandTheme.of(context).background
KeroseneBrandTheme.of(context).surface
KeroseneBrandTheme.of(context).border
KeroseneBrandTheme.of(context).textPrimary
KeroseneBrandTheme.of(context).textSecondary

// Static brand accent tokens:
KeroseneBrandTokens.brand    // gold #D6A84F
KeroseneBrandTokens.success  // green
KeroseneBrandTokens.warning  // amber
KeroseneBrandTokens.error    // red
KeroseneBrandTokens.bitcoin  // orange #F59E0B
```

### 1.4 Migration Constraint

- New code MUST NOT use `Color(0x...)` inline hex or `Colors.*` Material constants.
- Use semantic tokens from `KeroseneBrandTokens`, `KeroseneBrandTheme.of(context)`, or `AppColors.*` for raw hex values.
- Scene renderers (aurora, glow, atmosphere) are exempt — their gradient stops are deliberate visual effects.

## 2. Typography System

### 2.1 Font Families

| Role | Font (loaded) | `AppTypography` method | `AppTypography` constant |
|------|--------------|----------------------|-------------------------|
| Display / hero / H1 | **Playfair Display** | `playfairDisplay()` | `displayFontFamily` |
| UI / body / descriptions | **Plus Jakarta Sans** | `inter()` *(nome legado)* | `bodyFontFamily` |
| Hashes / technical IDs | **JetBrains Mono** | `ibmPlexMono()` *(nome legado)* / `financial()` | `monoFontFamily` |

> **Nota:** O metodo `inter()` carrega **Plus Jakarta Sans** via `GoogleFonts.plusJakartaSans()`. O nome "inter" e legado — a fonte real e Plus Jakarta Sans.
> O metodo `ibmPlexMono()` carrega **JetBrains Mono** via `GoogleFonts.jetBrainsMono()`. O nome "ibmPlexMono" e legado — a fonte real e JetBrains Mono.

### 2.2 Weight System

Linear uses custom half-step weights instead of standard 600/700 bold:

| Weight | `AppTypography` constant | Usage |
|--------|------------------------|-------|
| 400 | `w400` | Body text, descriptions |
| 500 | `w500` | Medium emphasis |
| **510** | `w510` | **Headings, nav, buttons** — signature display weight |
| **590** | `w590` | **Emphasis, amounts** — half-step past medium for controlled emphasis |

> **DO NOT** use `FontWeight.w600` or `FontWeight.w700` — the half-step weights are the entire brand voice.

### 2.3 Type Scale

| Role | Size | Line Height | Letter Spacing | `AppTypography` method | Font loaded |
|------|------|-------------|----------------|----------------------|-------------|
| caption | 12px | 1.6 | -0.12px | `inter(fontSize: 12, ...)` | Plus Jakarta Sans |
| body | 15px | 1.5 | -0.15px | `inter(fontSize: 15, fontWeight: w400, ...)` | Plus Jakarta Sans |
| heading-sm | 24px | 1.33 | -0.288px | `playfairDisplay(fontSize: 24, ...)` | Playfair Display |
| heading | 32px | 1.2 | -0.416px | `playfairDisplay(fontSize: 32, ...)` | Playfair Display |
| display | 48px | 1.13 | -1.056px | `playfairDisplay(fontSize: 48, ...)` | Playfair Display |

### 2.4 API

```dart
// Display / H1 — loads Playfair Display
AppTypography.playfairDisplay(fontSize: 32, color: ..., fontWeight: w510)

// Body / UI text — loads Plus Jakarta Sans (apesar do nome "inter")
AppTypography.inter(fontSize: 15, color: ..., fontWeight: w400)

// Technical / mono — loads JetBrains Mono
AppTypography.financial(fontSize: 13, color: ..., fontWeight: w400)
AppTypography.ibmPlexMono(fontSize: 13, color: ...) // nome legado, carrega JetBrains Mono

// Amount hero (tabular figures, weight 590) — Plus Jakarta Sans
AppTypography.inter(fontSize: 48, color: ..., fontWeight: w590)
```

## 3. Spacing System (4pt Grid)

Base unit: **4px**. Semantic aliases follow the Linear scale:

| Name | Value | `AppSpacing` constant |
|------|-------|----------------------|
| — | 2px | `xxs` |
| 4 | 4px | `xs`, `spacing4` |
| 8 | 8px | `sm`, `spacing8` |
| 12 | 12px | `md`, `spacing12` |
| 16 | 16px | `base`, `spacing16` |
| 20 | 20px | `lg`, `spacing20` |
| 24 | 24px | `xl2`, `spacing24` |
| 28 | 28px | `xl` |
| 32 | 32px | `module`, `spacing32` |
| 40 | 40px | `xxl` |
| 48 | 48px | `section`, `spacing48` |
| 56 | 56px | `xxxl`, `spacing56` |
| 80 | 80px | `spacing80` |

## 4. Component Theme

### 4.1 Buttons

- **Shape**: pill (9999px radius) — never square or 8px
- **Primary**: outlined (1px solid #f7f8f8), transparent background, no fill, no shadow
- **Ghost**: text-only at 14px weight 510, color #8a8f98, hover → #f7f8f8
- **Elevation**: none — confidence comes from contrast, not depth

### 4.2 Inputs

- **Radius**: 4px
- **Fill**: Carbon surface (#141516)
- **Border**: 1px Smoke surface (#23252a)
- **Focus**: no ring — just border shift to Ash (#34343a)
- **Height**: ~32px, padding 8px 12px

### 4.3 Cards

- **Radius**: 8px
- **Fill**: Graphite surface (#1c1c1f)
- **Border**: 1px Smoke surface (#23252a)
- **Elevation**: none (1px hairline only)

### 4.4 Navigation

- **Top bar**: sticky, full-bleed, background #08090a, 1px bottom border #23252a, height 56px
- **Tab nav**: horizontal, no underline indicator, 16px gap between items
- **Sidebar** (admin): width 240px (expanded), 64px (collapsed)

### 4.5 Shadows

Linear deliberately avoids drop shadows. Separation is achieved through:

1. **Stacked gray surfaces** — 5 levels of near-black
2. **1px hairline borders** — #23252a to #34343a
3. **Inner stroke** — rgba(255,255,255,0.03) 0px 0px 0px 1px inset

```dart
// No shadow
AppShadows.none

// 1px stroke
AppShadows.subtle  // ferriteBorder 0px 0px 0px 1px
```

## 5. Do's and Don'ts

### Do

- Use 9999px radius for all action buttons, nav items, and tag pills — pill-shaped controls are the signature geometry.
- Set primary text and borders to #f7f8f8 against #08090a canvas — the near-white-on-near-black contrast is the entire brand.
- Use w510 for headings and w590 for emphasis — avoid 600/700 bold, the half-step weights are the signature.
- Apply negative letter-spacing across all sizes: -0.010em for body, scaling to -0.022em at display 48px.
- Layer surfaces with the gray stack: #08090a → #141516 → #1c1c1f → #23252a → #2d2e31.
- Use 1px hairline borders for all dividers, card edges, and input frames — never use drop shadows.
- Reserve JetBrains Mono for inline code references and command examples only.

### Don't

- Do not introduce chromatic brand colors, accent fills, or gradient CTAs — the 3% colorfulness is a discipline, not a limitation.
- Do not use 600/700 font weights for headings — Linear's typographic voice is weight 510/590, not bold.
- Do not apply drop shadows to cards or panels — use surface-level gray shifts instead.
- Do not use filled buttons with solid backgrounds for primary actions — outlined pill buttons (1px #f7f8f8 border) are the only action style.
- Do not break the compact 4px base spacing rhythm with large gaps — section gaps stay at 48px, element gaps at 6-8px.
- Do not use rounded corners larger than 8px on cards — 4-5px and 8px are the only card radii; 9999px is pill-only.
- Do not use 600/700 bold for inline emphasis in body text — use weight 590 or rely on color shift to #f7f8f8.

## 6. Migration Guide

### Step 1: Replace inline hex colors

```dart
// Before
Color get _bg => const Color(0xFF141516)
Color get _text => const Color(0xFFF7F8F8)

// After
Color get _bg => KeroseneBrandTokens.surface
Color get _text => KeroseneBrandTokens.textPrimary
```

### Step 2: Replace light/dark ternaries

```dart
// Before
final labelColor = dark ? const Color(0xFFC8CCD4) : const Color(0xFF1C1C1F);

// After
final labelColor = dark
    ? KeroseneBrandTheme.dark.textSecondary
    : KeroseneBrandTheme.light.textSecondary;
```

### Step 3: Replace status colors

```dart
// Before
static const Color _green = Color(0xFF34C759);

// After
static Color get _green => KeroseneBrandTokens.success;
```

### Step 4: Replace Colors.*

```dart
// Before
color: Colors.black.withValues(alpha: 0.48);

// After
color: AppColors.hexFF000000.withValues(alpha: 0.48);
```

## 7. SDD Index Entry

When modifying design system files, reference:

```
[SDD Check: docs/frontend/DESIGN_SYSTEM.md — Section <X.Y>]
```

When modifying features that consume design system tokens, cross-check the Design Rules (Section 5) above.
