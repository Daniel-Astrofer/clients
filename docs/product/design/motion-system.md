# Motion System

> Status: Draft | Applies-to: mobile · web · admin
> Last revised: 2026-07-31

## Why this exists

`KeroseneMotion` provides 35+ duration tokens and 5 curves. Without categorization, agents pick durations arbitrarily ("this feels right"). This document categorizes every token by semantic purpose and provides a decision matrix: "when this happens, use that motion."

---

## Motion categories

### 1. Functional motion
**Purpose:** Explain what happened to the interface. Every state change in a widget.

| Trigger | Duration | Curve | Token |
|---------|----------|-------|-------|
| Button press feedback | 120ms | easeOutCubic | `KeroseneMotion.fast` |
| Toggle/switch | 180ms | easeOutCubic | `KeroseneMotion.short` |
| Item removal from list | 180ms | easeInCubic | `KeroseneMotion.short` + `KeroseneMotion.exit` |
| Value update (non-balance) | 260ms | easeOutExpo | `KeroseneMotion.medium` |
| Error state appearing | 260ms | easeOutCubic | `KeroseneMotion.medium` |
| Snackbar/notice enter | 260ms | easeOutQuart | `KeroseneMotion.medium` + `KeroseneMotion.entrance` |
| Notice dismiss | 180ms | easeInCubic | `KeroseneMotion.short` + `KeroseneMotion.exit` |

**Technology:** Flutter `AnimatedContainer`, `AnimatedOpacity`, `AnimatedPositioned`, `flutter_animate`.

---

### 2. Continuity motion
**Purpose:** Preserve the perceptual relationship between screens. The user should understand "this screen is a detail of that row."

| Trigger | Duration | Curve | Token |
|---------|----------|-------|-------|
| Push to new screen | 136ms | easeOutQuart | `KeroseneMotion.pageIn` |
| Pop back | 92ms | easeInCubic | `KeroseneMotion.pageOut` |
| Hero element (e.g., amount → detail) | 260ms | easeOutExpo | `KeroseneMotion.medium` + `KeroseneMotion.emphasized` |
| Wallet selector expand | 260ms | easeOutCubic | `KeroseneMotion.medium` |

**Technology:** `Hero` widget, `keroseneHorizontalRoute`, custom `PageTransitions`.

**Continuity rules:**
- The amount value must maintain its screen position when transitioning from edit → review → confirmation
- The selected wallet badge must not disappear and reappear — it expands or transforms
- A transaction row that opens a detail should Hero the amount + counterparty into the detail header
- Page transitions must respect direction: push = right→left (LTR), pop = left→right. Modal bottom-up is the exception.

---

### 3. Brand motion
**Purpose:** Rare, high-impact moments. Used with restraint — perhaps 2-3 times per full user session.

| Trigger | Duration | Curve | Token |
|---------|----------|-------|-------|
| Payment confirmed | 2600ms | Custom (Rive) | `KeroseneMotion.ceremonial` |
| Secure operation authorized | 5200ms | Custom (Rive) | `KeroseneMotion.secureLoop` |
| Balance odometer ceremony (first appearance) | 1000ms | easeOutExpo | `KeroseneMotion.odometerCeremony` |
| Balance odometer update (real delta) | 700ms | easeOutExpo | `KeroseneMotion.odometerUpdate` |
| Passkey verification scene | 900ms | Custom (Rive) | `KeroseneMotion.passkeyScene` |
| TOTP code transition | 850ms | easeOutCubic | `KeroseneMotion.totpTransition` |

**Technology:** Rive state machines for complex multi-state animations (payment status, security). Flutter `AnimationController` for simpler ceremonies (odometer).

**Rule:** Brand motion must be tied to a real operation state. A Rive animation that plays as a video regardless of actual payment status is prohibited.

---

### 4. Ambient motion
**Purpose:** Atmosphere, depth, and slow background presence. Must never compete with financial content.

| Trigger | Duration | Curve | Token |
|---------|----------|-------|-------|
| Aurora glow displacement | 20s | Linear | `KeroseneMotion.ambient` |
| Hero loop (background) | 2200ms | Linear | `KeroseneMotion.heroLoop` |
| Wallet background loop | 4s | Linear | `KeroseneMotion.walletLoop` |
| Slow surface transition | 1000ms | easeOutCubic | `KeroseneMotion.calm` |

**Technology:** Fragment shaders (`.frag`) for aurora/glow. `CustomPainter` for slow-displacement effects. `Ticker`-driven, not `AnimationController` that rebuilds the widget tree.

**Performance rules (CRITICAL):**
- Ambient animations must run on their own `RepaintBoundary` — never trigger financial widget rebuilds
- Shader complexity must be tested on entry-level GPU (Mali-G52, Adreno 618)
- Glow intensity must reduce when financial content is being interacted with
- `VisibilityDetector`: stop animation when off-screen
- `reduceMotion`: ambient motion is the FIRST thing removed

---

### 5. Loading & feedback motion

| Trigger | Duration | Token |
|---------|----------|-------|
| Minimum loading display (avoid flash) | 3s | `KeroseneMotion.loadingMinimum` |
| Loading with retry (medium) | 6s | `KeroseneMotion.loadingRetryMedium` |
| Loading with retry (long) | 12s | `KeroseneMotion.loadingRetryLong` |
| Loading timeout | 15s | `KeroseneMotion.loadingTimeout` |
| Notice hold (info) | 3s | `KeroseneMotion.noticeHold` |
| Notice hold (extended/error) | 4s | `KeroseneMotion.noticeExtendedHold` |
| Notification hold | 5s | `KeroseneMotion.notificationHold` |
| Notification hold (long) | 6s | `KeroseneMotion.notificationLongHold` |
| Offline retry pulse | 520ms | `KeroseneMotion.offlineRetryPulse` |
| Offline retry interval | 4s | `KeroseneMotion.offlineRetryInterval` |
| Startup connection tick | 420ms | `KeroseneMotion.startupConnectionProgressTick` |
| Startup timeout | 55s | `KeroseneMotion.startupConnectionTimeout` |

---

### 6. Micro-interaction timing

| Use case | Stagger | Token |
|----------|---------|-------|
| List item entry (general) | 60ms per item | `KeroseneMotion.listStagger` |
| Auth form field entry | 34ms per field | `KeroseneMotion.authStagger` |
| Surface element stagger | 28ms per element | `KeroseneMotion.surfaceStagger` |
| Compact element stagger | 45ms per element | `KeroseneMotion.compactStagger` |
| Generic stagger (default) | 50ms | `KeroseneMotion.microStagger` |

Use `KeroseneMotion.stagger(index, step: ...)` — it clamps to max 100 items and returns a `Duration`.

---

### 7. NFC interaction timing

| Phase | Duration | Token |
|-------|----------|-------|
| NFC scene intro animation | 1600ms | `KeroseneMotion.nfcSceneIntro` |
| NFC ready + listening loop | 3900ms | `KeroseneMotion.nfcSceneReady` |

---

## Curves and when to use them

| Curve | Token | Character | Use for |
|-------|-------|-----------|---------|
| easeOutCubic | `KeroseneMotion.standard` | Smooth deceleration, neutral | Default. Most functional animations. |
| easeOutExpo | `KeroseneMotion.emphasized` | Strong deceleration, dramatic | Brand moments, ceremonial. Confirmation transitions. |
| easeOutQuart | `KeroseneMotion.entrance` | Between cubic and expo | Screen entrances, elements appearing. |
| easeInCubic | `KeroseneMotion.exit` | Smooth acceleration | Elements disappearing, screen exits. |
| easeOutBack | `KeroseneMotion.spring` | Overshoot, playful | Onboarding, education, non-financial moments ONLY. |

**CRITICAL:** `KeroseneMotion.spring` (easeOutBack) is FORBIDDEN for:
- Balance displays
- Transaction confirmations
- Payment status transitions
- Any widget displaying or handling money

---

## Technology mapping

| Animation type | Technology | File reference |
|---------------|-----------|----------------|
| Widget state transitions | `AnimatedContainer`, `AnimatedOpacity` | Flutter SDK |
| Enter/exit effects | `flutter_animate` package | `pubspec.yaml` |
| Screen push/pop | `keroseneHorizontalRoute` | `lib/core/navigation/app_page_transitions.dart` |
| Shared element continuity | `Hero` widget | Flutter SDK |
| Payment status (multi-state) | Rive state machine | `lib/design_system/foundation/assets/animation/kerosene_rive.dart` |
| Atmosphere/aurora/glow | Fragment shader + `CustomPainter` | `assets/shaders/home_aurora.frag`, `lib/features/home/scene/renderer/` |
| Background loops | Lottie | `lib/design_system/foundation/assets/animation/kerosene_lottie.dart` |
| Haptic feedback | `HapticFeedback` + `KeroseneInteraction` | `lib/design_system/foundation/interaction/kerosene_interaction.dart` |

---

## Performance budget

| Rule | Threshold |
|------|-----------|
| Primary interaction jank | 0 perceptible frames dropped at 60Hz |
| Measurement mode | Profile mode ONLY (never debug mode) |
| Ambient animation rebuild scope | Must NOT include financial provider widgets |
| Per-item effects in lists | Prohibited (no per-item blur, shader, or CustomPainter in lists) |
| Shader GPU floor | Tested on Mali-G52 / Adreno 618 at 60fps |
| `reduceMotion` | Removes all non-functional motion. Functional motion collapses to `instant`. |
| Naive animated `Opacity` | Prohibited — use `AnimatedOpacity` or prefer compositing |
| Transform vs layout | Prefer `Transform` over `AnimatedContainer` size changes during animation |

### `reduceMotion` behavior
When `MediaQuery.of(context).disableAnimations == true`:
- Functional: collapses to `instant` (0ms) — state still changes, just without transition
- Continuity: page transitions become `instant`
- Brand: still plays (ceremonial confirmation is semantic, not decorative) but at accelerated speed
- Ambient: removed entirely (no glow displacement, no hero loop)
- Loading: spinners replaced with static indicator
- Stagger: all delays collapse to 0

---

## Token & file map

| Category | Source file |
|----------|------------|
| All motion tokens | `lib/core/motion/app_motion.dart` |
| Animation wrappers | `lib/design_system/foundation/assets/animation/` |
| Page transitions | `lib/core/navigation/app_page_transitions.dart` |
| Haptics | `lib/design_system/foundation/interaction/kerosene_interaction.dart` |
| Shaders | `assets/shaders/` |

---

## Do / Don't

- [ ] DO categorize every animation as functional, continuity, brand, or ambient
- [ ] DO use `KeroseneMotion` tokens — never raw `Duration(milliseconds: ...)`
- [ ] DO tie brand animations to real operation state (Rive state machine)
- [ ] DO isolate ambient animations on their own `RepaintBoundary`
- [ ] DO test shaders on entry-level GPU
- [ ] DO honor `reduceMotion` globally
- [ ] DON'T use `spring`/`easeOutBack` for financial widgets
- [ ] DON'T animate all components on screen entry
- [ ] DON'T use skeleton loaders when previous state can be preserved
- [ ] DON'T use naive `Opacity` animation — prefer compositing
- [ ] DON'T run ambient animations that rebuild financial widget trees

---

## Verification

- [ ] Every animation in feature code references a `KeroseneMotion` token?
- [ ] No raw `Duration(milliseconds: ...)` or `Curves.*` outside exempt files?
- [ ] `reduceMotion` removes non-essential movement?
- [ ] Profile mode: home screen maintains 60fps during ambient animation?
- [ ] Per-item effects absent from lists?
