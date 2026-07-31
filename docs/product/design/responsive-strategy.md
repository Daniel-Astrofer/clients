# Responsive Strategy

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

Kerosene runs on phones, tablets, laptops, and wide desktop monitors. The design system provides the `KeroseneWindowClass` breakpoints. This document defines *behavior* at each breakpoint — what changes, what doesn't, and how to test.

---

## 1. Breakpoints

Defined in `lib/core/responsive/kerosene_responsive.dart`:

| Class | Width | Device |
|-------|-------|--------|
| Compact | < 600pt | Phone (portrait & landscape) |
| Medium | 600–960pt | Tablet portrait, small desktop |
| Expanded | 960–1280pt | Tablet landscape, desktop |
| Wide | ≥ 1280pt | Desktop, large monitors |

---

## 2. Layout per breakpoint

### Compact (< 600pt)
- **Navigation:** Bottom bar (`AppPrimaryNavigation`), 4-5 destinations
- **Content:** Single column, full-width surfaces
- **Modals:** Full-screen or bottom sheet
- **Sidebar:** Not applicable
- **Typography:** Same scale, no size reduction
- **Touch:** Primary input method

### Medium (600–960pt)
- **Navigation:** Bottom bar OR left rail (icon-only, 64px)
- **Content:** Single column with comfortable max-width (~560pt)
- **Modals:** Centered dialog for simple, bottom sheet for complex
- **Lists:** Can show 2 columns if content benefits (e.g., wallet grid)
- **Touch/pointer:** Both supported

### Expanded (960–1280pt)
- **Navigation:** Persistent sidebar (240px) OR top bar with horizontal tabs
- **Content:** Can split into 2 columns (e.g., list + detail)
- **Modals:** Centered dialog
- **Hover states:** Required on all interactive elements
- **Keyboard:** Shortcuts for navigation, actions

### Wide (≥ 1280pt)
- **Navigation:** Persistent sidebar (240px)
- **Content:** Content-constrained max-width (~1200pt) centered, atmospheric margins
- **Multi-pane:** Primary + secondary panel (e.g., home balance + market chart side-by-side)
- **Hover states:** Required
- **Keyboard:** Full shortcut support

---

## 3. Component adaptation

### Navigation
| Component | Compact | Medium | Expanded+ |
|-----------|---------|--------|-----------|
| Primary nav | Bottom bar | Bottom rail or sidebar | Sidebar (240px) |
| Back button | Top bar or gesture | Top bar | Breadcrumb or sidebar highlight |
| Tab navigation | Horizontal scroll | Horizontal tabs | Sidebar sections |
| Settings | Full-screen push | Full-screen push | Sidebar + content panel |

### Financial surfaces
| Component | Compact | Medium+ |
|-----------|---------|---------|
| Balance display | Centered, full-width | Left-aligned, can share row with actions |
| Action cluster | Below balance, 2-3 buttons | Right-aligned or toolbar |
| Transaction list | Full-width rows | Can split: list left, detail right |
| Send flow | Full-screen steps | Steps can share panel with context |

### Admin (web-only)
Admin is Expanded+ by default:
- Persistent sidebar (240px expanded, 64px collapsed)
- Content area fills remaining width
- Tables/data grids use full available width
- Detail panels open as right-side split

---

## 4. What does NOT change

- Color tokens (identical across all breakpoints)
- Typography scale (identical across all breakpoints)
- Spacing tokens (identical across all breakpoints)
- Radii (identical across all breakpoints)
- Motion tokens (identical across all breakpoints)
- Content and terminology (identical across all breakpoints)

What changes: **layout composition only**. Tokens are sacred across platforms.

---

## 5. Desktop-specific requirements

### Hover states
Every interactive element on pointer-capable devices must have a visible hover state:
- Buttons: border color shift (Ash → Snow on hover)
- List items: surface level shift (Carbon → Graphite on hover)
- Sidebar items: text color shift (Fog → Snow on hover)
- Links: underline on hover
- Cards: surface level shift, no scale transform

### Keyboard shortcuts

| Shortcut | Action | Context |
|----------|--------|---------|
| `Ctrl+K` | Command palette / search | Global |
| `Ctrl+N` | New transaction | Home |
| `Ctrl+B` | Toggle sidebar | Admin |
| `Esc` | Close modal / go back | Global |
| `Ctrl+/` | Show keyboard shortcuts | Global |

### Focus indicators
- Visible focus ring on all interactive elements
- Logical tab order (left→right, top→bottom)
- Skip-to-content link for screen readers

---

## 6. Testing per breakpoint

### Golden tests
Every screen must have golden baselines at these sizes:
- 390 × 844 (Compact, iPhone 14)
- 600 × 960 (Medium, tablet)
- 1024 × 768 (Expanded, small desktop)
- 1440 × 900 (Wide, desktop)
- 1920 × 1080 (Wide, large desktop)

### Responsive checks
- [ ] No horizontal scroll at any breakpoint
- [ ] No content truncated or overflowing
- [ ] Touch targets ≥44pt at all breakpoints
- [ ] Text remains readable at 200% scale
- [ ] Navigation adapts correctly (bottom → sidebar)

---

## Token & file map

| Concept | Source file |
|---------|------------|
| Breakpoints | `lib/core/responsive/kerosene_responsive.dart` |
| Primary navigation | `lib/design_system/components/generic/app_primary_navigation.dart` |
| Admin sidebar | `lib/features/web_admin/` |
| Golden harness | `test/goldens/golden_harness.dart` |

---

## Do / Don't

- [ ] DO use `KeroseneWindowClass` for breakpoint decisions
- [ ] DO adapt layout composition at each breakpoint
- [ ] DO add hover states on all pointer-capable interactive elements
- [ ] DO test at all 5 golden resolution sizes
- [ ] DO preserve identical tokens at all breakpoints
- [ ] DON'T cap desktop content at phone width
- [ ] DON'T use bottom navigation on Expanded+
- [ ] DON'T change typography scale per breakpoint
- [ ] DON'T hide content on desktop that exists on mobile
- [ ] DON'T add horizontal scroll as a layout solution

---

## Verification

- [ ] Run golden tests at all 5 resolutions — no overflow or truncation?
- [ ] Hover states visible on all interactive elements at Expanded+?
- [ ] Navigation adapts: bottom bar (Compact) → sidebar (Expanded+)?
- [ ] No horizontal scrollbars at any breakpoint?
- [ ] Touch targets ≥44pt at all sizes?
