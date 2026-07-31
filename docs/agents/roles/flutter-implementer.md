# Role: Flutter Implementer

> Writes code? Yes — full Flutter implementation
> Inputs: Screen contract, approved visual composition, existing components
> Outputs: Working screen with all states, providers, navigation, tests

## Responsibility

Implement the complete screen: Riverpod providers, navigation, real data integration, all states from the contract, widget tests, golden tests, and accessibility verification. The Implementer works from an approved visual composition — they don't design from scratch.

## Process

1. Read the screen contract (Flow Architect output)
2. Study the approved visual composition (Visual Director output)
3. Apply motion implementation (Motion Specialist output or self-implement following motion-system.md)
4. Implement in this order:
   a. **State layer** — Riverpod providers for all states in the contract
   b. **View state** — Transform domain data into UI state (separate from widgets)
   c. **Layout** — Implement the approved composition using existing components
   d. **States** — Implement every state: loading, empty, error, offline, success, pending
   e. **Integration** — Connect to navigation, real providers, deferred loading
   f. **Motion** — Add animations per motion contract
   g. **Tests** — Widget tests, golden tests, accessibility checks

## Code structure

```dart
// Feature structure:
lib/features/<feature>/
  domain/
    entities/     — Pure data objects
  application/
    providers/    — Riverpod providers, use cases
    state/        — UI state classes (separate from domain entities)
  presentation/
    screens/      — One file per screen (≤700 lines)
    widgets/      — Screen-specific widgets
```

## Implementation rules

1. **Tokens only.** No `Color(0x...)`, `BorderRadius.circular(...)`, `EdgeInsets.only(top: 18)`, `Duration(milliseconds: 350)` in feature code.

2. **State first.** The widget only renders what the provider emits. Never compute state in `build()`.

3. **All states.** Every state from the contract must have a corresponding UI state and widget branch.

4. **RepaintBoundary.** Wrap heavy/ambient subtrees. Never wrap the entire screen (defeats the purpose).

5. **Deferred loading.** Use `deferred as` for screen imports when the screen is not on the critical path.

6. **Error boundaries.** Every async operation has error handling. Errors surface as `StateFeedbackView`, never as uncaught exceptions or SnackBars.

7. **No premature abstraction.** One screen, one file. Extract to shared widgets only when the same pattern is used in ≥2 screens.

## Tests

### Widget tests (required)
```dart
testWidgets('shows loading state', (tester) async { ... });
testWidgets('shows error state with retry', (tester) async { ... });
testWidgets('shows empty state with action', (tester) async { ... });
testWidgets('shows success state', (tester) async { ... });
testWidgets('dominant action triggers callback', (tester) async { ... });
```

### Golden tests (required for every screen)
```dart
testGoldens('screen at Compact', (tester) async {
  await pumpGoldenAt(tester, MyScreen(), Size(390, 844));
  await screenMatchesGolden(tester, 'my_screen_compact');
});
// Repeat for all 5 resolutions
```

### Accessibility checks (required)
```dart
testWidgets('meets accessibility guidelines', (tester) async {
  await tester.pumpWidget(MyScreen());
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
});
```

## Quality gates

- [ ] `flutter analyze` passes with no new warnings
- [ ] All states from contract have widget tests
- [ ] Golden tests pass at all 5 resolutions
- [ ] Accessibility checks pass
- [ ] No raw tokens in feature code
- [ ] File size ≤700 lines (or documented exception)
- [ ] Deferred loading for non-critical screens
- [ ] Error handling on all async operations
- [ ] Riverpod providers in `application/providers/`, not `presentation/`

## Tools

- Riverpod for state management
- go_router for navigation
- `flutter_animate` for simple animations
- `golden_toolkit` for golden tests
- Flutter accessibility APIs for checks
