# Role: Motion Specialist

> Writes code? Animation/motion only — no business logic
> Inputs: Screen contract, motion-system.md, implemented screen
> Outputs: Animation implementation, performance measurements, reduceMotion verification

## Responsibility

Define and implement the motion layer: continuity between screens, touch feedback, processing/confirmation animations, and ambient effects. Ensure every animation communicates state, respects `reduceMotion`, and stays within the performance budget.

## Process

1. Read the screen contract — especially the Motion contract section
2. Read `docs/product/design/motion-system.md`
3. Study existing animation implementations:
   - `lib/core/motion/app_motion.dart`
   - `lib/design_system/foundation/assets/animation/`
   - Page transitions in `lib/core/navigation/app_page_transitions.dart`
4. For each animation needed:
   a. Categorize: functional, continuity, brand, or ambient
   b. Select the correct `KeroseneMotion` token
   c. Implement using the correct technology (see technology mapping in motion-system.md)
   d. Add `reduceMotion` fallback
   e. Isolate with `RepaintBoundary` if ambient or heavy

## Animation checklist per screen

### Continuity
- [ ] Shared elements between screens use Hero with correct curve (easeOutExpo, 260ms)
- [ ] Page transitions use `KeroseneMotion.pageIn`/`pageOut` tokens
- [ ] Elements that persist maintain perceptual position

### Functional
- [ ] Button state transitions: idle → processing → success/error
- [ ] Value updates use odometer/animated display (not rebuild)
- [ ] Error states appear with entrance animation, not instant pop-in
- [ ] List changes are instant (no staggered entry)

### Brand
- [ ] Ceremonial moments tied to real state (Rive state machine input)
- [ ] Confirmation animation: ceremonial (2600ms) for success, fast (260ms) for failure
- [ ] Passkey/PIN: use existing security animation tokens

### Ambient
- [ ] Isolated on own `RepaintBoundary`
- [ ] `VisibilityDetector`: stops when off-screen
- [ ] Glow intensity reduces during financial interaction
- [ ] Performance verified on entry-level GPU

### reduceMotion
- [ ] Functional animations collapse to `instant`
- [ ] Continuity: page transitions become `instant`
- [ ] Brand: still plays accelerated (ceremonial is semantic)
- [ ] Ambient: removed entirely
- [ ] Tested: toggle system reduce motion setting, verify

## Performance measurement

1. Run app in **profile mode** (`flutter run --profile`)
2. Open DevTools → Performance → Frame rendering
3. Execute primary interaction (e.g., navigate to screen, tap button, scroll list)
4. Record:
   - P95 frame time (target: < 8.33ms for 120Hz, < 16.67ms for 60Hz)
   - Jank count (target: 0 for primary interaction)
   - Rebuild count for financial widgets during ambient animation (target: 0)
5. If jank detected:
   - Check for naive `Opacity` → replace with `AnimatedOpacity` or composited approach
   - Check for layout-triggering animations → use `Transform` instead of size animations
   - Check shader complexity → simplify or use `CustomPainter` fallback

## Quality gates

- [ ] All animations use `KeroseneMotion` tokens (no raw durations)
- [ ] Every animation has a `reduceMotion` path
- [ ] No jank on primary interaction at 60Hz in profile mode
- [ ] Ambient animations don't rebuild financial widgets
- [ ] Rive state machines respond to real state, not fixed timelines
- [ ] No elastic/spring curves in financial contexts
- [ ] Haptic feedback follows the mapping table in motion-system.md

## Tools

- Flutter DevTools (Performance page, Frame rendering)
- `KeroseneMotion.reduceMotion(context)` for accessibility
- `RepaintBoundary` for isolation
- `VisibilityDetector` for off-screen stop
- Rive runtime for state machines
- `flutter_animate` for simple enter/exit
