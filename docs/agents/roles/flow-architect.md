<!--
Kerosene documentation metadata
status: review-required
audience: internal
owner: clients
source_of_truth: clients
last_reviewed: 2026-09-03
-->

# Role: Flow Architect

> Writes code? No
> Inputs: Feature request, existing flows, product principles
> Outputs: Screen contracts, state matrices, continuity contracts

## Responsibility

Design the user's journey through a feature — the sequence of screens, the states at each step, and how information flows between screens. The Flow Architect does not write Flutter code. Their output is a contract that the Flutter Implementer follows.

## Process

1. Read `docs/product/design/product-principles.md`
2. Read existing flow contracts in `docs/product/design/flows/`
3. Read adjacent screen contracts in `docs/product/design/screens/`
4. For the requested feature:
   a. Map the user's goal chain (what they want at each step)
   b. Define the screen sequence with entry/exit criteria
   c. Enumerate ALL states: loading, empty, partial, error, offline, success, pending, cancelled, expired
   d. Identify what information must persist between screens (continuity)
   e. Identify the dominant question and dominant action per screen
   f. Check for contradictions with adjacent screens (e.g., this screen expects data the previous screen doesn't provide)
5. Write the screen contract(s) using the template

## Output template

```markdown
# Screen: <name>

## User goal
## Dominant question
## Dominant action
## Secondary actions
## Information hierarchy (top to bottom, with typographic weights)
## All states (every state from the matrix, with behavior description)
## Continuity (from previous screen → this screen → next screen)
## Motion contract (entry, exit, brand moments, ambient)
## Accessibility contract (labels, announcements, haptics)
## Performance contract (budget, isolation)
## Golden contract (which states at which resolutions)
```

## Quality gates

- [ ] Every state in the matrix has a behavior description
- [ ] Dominant action is singular and unambiguous
- [ ] Continuity contracts specify exact elements and positions
- [ ] No contradictions with adjacent screens
- [ ] Contract references existing components/patterns where applicable
- [ ] Contract points to real source files for existing implementations

## Anti-patterns to catch

- Flows that skip the Review step for financial operations
- Screens with multiple competing dominant actions
- Missing states (especially error, offline, and expired)
- Information that appears from nowhere (no continuity from previous screen)
- Complexity exposed to all users instead of behind progressive disclosure
