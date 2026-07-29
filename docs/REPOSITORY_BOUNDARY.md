# Repository boundary

This repository is the canonical source for Kerosene client applications,
shared Dart code, design system, API clients and client-side verifiers.

The Flutter application remains at the repository root intentionally. Moving a
single application under `apps/consumer` would add path churn without creating
an independent release boundary. Additional applications may introduce an
`apps/` and `packages/` workspace when they exist.

Clients consumes versioned protocols and APIs. It must not read source files
from the archived monorepo or service repositories.
